Param
(
    [Parameter(Mandatory=$false,Position=0)]
    [string]
        #Instrumentation key for AppInsights instance to log to
    $InstrumentationKey,
    [Parameter(Mandatory=$false,Position=1)]
    [string]
        #Name of the application that is producing the logs
        #For automation accounts, it can be name of automation account
        #Is automatically registered to metadata sent with every piece data logged
    $Application,
    [Parameter(Mandatory=$false,Position=2)]
    [string]
        #Name of the component producing the logs
        #For automation accounts, it can be name of the runbook
        #Is automatically registered to metadata sent with every piece data logged
        $Component,
    [Parameter(Mandatory=$false,Position=3)]
    [string]
    $Role,
        #Identifier of role sending the data
        #For automation accounts, it can be useful when runbook is running on more hosts, e.g. in case of hybrid workers
    [Parameter(Mandatory=$false,Position=4)]
    [string]
        #Identifier of instance sending the data
        #For automation accounts, it may be usefult for runbooks that run in multiple instances on the same hosts, e.g. runbooks with multiple configurations
    $Instance
)

#region Metadata manipulation
function Add-AiMetadata {
    <#
    .SYNOPSIS
        Registers additional metadata to be sent with all telemetry produced after registered - until removed by call of Remove-AiMetadata or Reset-AiMetadata
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
            #Name of metadata to be registered. Will become custom dimension of telemetry data
            #Allows for easy searching/filtering in ApplicationInsights logs
        $Name,
        [Parameter(Mandatory)]
        [string]
            #Value of metadata
        $Value
    )
    
    process {
        if(-not (IsInitialized)) {return}
        if($Name -in $script:ProtectedMetadata) {throw (new-object System.ArgumentException("Dimension $Name cannot be overwritten",'Name'))}

        $script:telemetryMetadata[$Name]=$Value
    }
}

function Remove-AiMetadata {
    <#
    .SYNOPSIS
        Unregisters additional metadata previously registered via Add-AiMetadata
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
            #Name of metadata to be unregistered
        $Name
    )
    
    process {
        if(-not (IsInitialized)) {return}
        if($Name -in $script:ProtectedMetadata) {throw (new-object System.ArgumentException("Dimension $Name cannot be removed",'Name'))}

        $script:telemetryMetadata.Remove($Name) | Out-Null
    }
}

function Reset-AiMetadata
{
    <#
    .SYNOPSIS
        Unregisters all additional metadata previously registered.
    #>
    process {
        if(-not (IsInitialized)) {return}
        $keys=@()
        foreach($key in $script:telemetryMetadata.Keys) {$keys+=$key}
        foreach($key in $Keys) {
            if($key -notin $script:ProtectedMetadata) {
                $script:telemetryMetadata.Remove($key) | Out-Null
            }
        }
    }
}
#endregion

Function Initialize-AiLogger
{
    <#
.SYNOPSIS
    Initializes logging infrastructure

.DESCRIPTION
    This command must be called before any other commands from module. It creates necessary structures for logging and connects toApplication Insights instance identified by intrumentation key.
    Command also registers custom dimensions to be sent with all data; dimensions are Application and Components named passed as parameter. This helps easy filter logs related to different apps and components stored in single AppInsights instance.
    Command also registers metric namespace for logging of standalone metrics via Write-AiMetric command.

.EXAMPLE
    Initialize-AiLogger -InstrumentationKey '9ccdf7c4-7dcb-4659-87b8-639126191720' -Application MyApp -Component 'MyAppComponent'

    #>
    Param
    (
        [Parameter(Mandatory)]
        [string]
            #AppInsights instrumentation key
        $InstrumentationKey,
        [Parameter(Mandatory)]
        [string]
            #Name of the application that is producing the logs
            #For automation accounts, it can be name of automation account
            #Is automatically registered to metadata sent with every piece data logged
        $Application,
        [Parameter(Mandatory)]
        [string]
            #Name of the component producing the logs
            #For automation accounts, it can be name of the runbook
            #Is automatically registered to metadata sent with every piece data logged
        $Component,
        [Parameter()]
        [string]
            #Identifier of role sending the data
            #For automation accounts, it can be useful when runbook is running on more hosts, e.g. in case of hybrid workers
        $Role,
        [Parameter()]
        [string]
            #Identifier of instance sending the data
            #For automation accounts, it may be usefult for runbooks that run in multiple instances on the same hosts, e.g. runbooks with multiple configurations
        $Instance
    )
    
    process
    {
        $script:telemetryClient=new-object Microsoft.ApplicationInsights.TelemetryClient
        $script:telemetryClient.InstrumentationKey = $InstrumentationKey
        $script:telemetryMetadata = New-Object 'System.Collections.Generic.Dictionary[String,String]'
        $script:telemetryMetadata['Application']=$Application
        $script:ProtectedMetadata+='Application'
        $script:telemetryMetadata['Component']=$Component
        $script:ProtectedMetadata+='Component'
        $script:MetricNamespace = "$Application`.$Component"
        if(-not [string]::IsNullOrEmpty($Role))
        {
            $script:TelemetryClient.Context.Cloud.RoleName=$Role
        }
        else {
            $script:TelemetryClient.Context.Cloud.RoleName = "$Application`.$Component"
        }    
        if(-not [string]::IsNullOrEmpty($Instance)) {
            $script:TelemetryClient.Context.Cloud.RoleInstance = $Instance
        }
    }
}

Function Write-AiTrace
{
    <#
    .SYNOPSIS
        Writes trace message with severity and optional custom metadata.
        Default severity level is Verbose
    
    .EXAMPLE
        Write-AiTrace 'Beginning processing'

    .EXAMPLE
        $meta = New-AiMetadata
        $meta['Context']='MyContext'
        Write-AiTrace -Message "Performed context-specific action" -AdditionalMetadata $meta
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
            #Message to be traced
        $Message,
        [Parameter()]
        [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]
            #Severity of message sent
        $Severity='Verbose',
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with trace
        $Metadata=$null
    )
    Process
    {
        if(-not (IsInitialized)) {return}
        $data = new-object Microsoft.ApplicationInsights.DataContracts.TraceTelemetry($Message, $Severity)
        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        foreach($key in $script:telemetryMetadata.Keys) {$data.Properties[$Key] = $script:telemetryMetadata[$key]}

        $script:telemetryClient.TrackTrace($data)
    }
}

Function Write-AiException
{
    <#
    .SYNOPSIS
        Traces exception along with optional custom metadata and metrics
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Exception]
            #Exception to be traced
        $Exception,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Optional metrics to be sent with exception
        $Metrics=$null,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with exception
        $Metadata=$null
    )
    Process
    {
        if(-not (IsInitialized)) {return}
        
        $data = new-object Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry($Exception)
        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        if($null -ne $Metrics) {
            foreach($key in $Metrics.Keys) {$data.Metrics[$Key] = $Metrics[$key]}
        }
        foreach($key in $script:telemetryMetadata.Keys) {$data.Properties[$Key] = $script:telemetryMetadata[$key]}
        $script:telemetryClient.TrackException($data)
    }
}

Function Write-AiMetric
{
    <#
    .SYNOPSIS
        Logs metric value without any aggregation along with optional custom metadata
    #>
    param (
        [Parameter(Mandatory)]
        [string]
            #Name of the metric
        $Name,
        [Parameter(Mandatory)]
        [double]
            #Value of the metric
        $Value,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with metric
        $Metadata=$null
    )
    Process
    {
        if(-not (IsInitialized)) {return}

        $data = new-object Microsoft.ApplicationInsights.DataContracts.MetricTelemetry($Name, $Value)
        $data.MetricNamespace = $script:MetricNamespace

        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        foreach($key in $script:telemetryMetadata.Keys) {$data.Properties[$Key] = $script:telemetryMetadata[$key]}

        $script:telemetryClient.TrackMetric($data)
    }
}

function Write-AiDependency
{
    param
    (
        [Parameter(Mandatory)]
        [string]
            #Name of endpoint (hostname or host identifier for server being called)
        $Target,
        [Parameter(Mandatory)]
        [string]
            #Name of the dependency type, such as FTP, SQL or HTTP
        $TypeName,
        [Parameter(Mandatory)]
        [string]
            #Name of the dependency, such as FileDownload, StoredProcedureCall
        $Name,
        [Parameter()]
        [string]
            #Dependency details
        $Data,
        [Parameter(Mandatory)]
        [DateTime]
            #When started
        $Start,
        [Parameter(Mandatory)]
        [TimeSpan]
            #duration of call
        $Duration,
        [Parameter()]
        [bool]
            #Whether or not call was successful
        $Success = $true
    )

    process
    {
        $dependencyData = new-object Microsoft.ApplicationInsights.DataContracts.DependencyTelemetry
        foreach($key in $script:telemetryMetadata.Keys) {$dependencyData.Properties[$Key] = $script:telemetryMetadata[$key]}
        $dependencyData.Type=$TypeName
        $dependencyData.Name=$Name
        $dependencyData.Timestamp=$Start
        $dependencyData.Duration = $Duration
        $dependencyData.Success = $Success
        $dependencyData.Target = $Target
        $dependencyData.Data = $Data
        
        $script:telemetryClient.TrackDependency($dependencyData)
    }
}

Function Write-AiEvent
{
    <#
    .SYNOPSIS
        Traces event along with optional custom metadata and metrics
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
            #Event to be traced
        $EventName,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Optional metrics to be sent with the event
        $Metrics=$null,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with the event
        $Metadata=$null
    )
    Process
    {
        if(-not (IsInitialized)) {return}

        $data = new-object Microsoft.ApplicationInsights.DataContracts.EventTelemetry($EventName)

        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        if($null -ne $Metrics) {
            foreach($key in $Metrics.Keys) {$data.Metrics[$Key] = $Metrics[$key]}
        }
        foreach($key in $script:telemetryMetadata.Keys) {$data.Properties[$Key] = $script:telemetryMetadata[$key]}
        $script:telemetryClient.TrackEvent($data)
    }
}

Function New-AiMetric
{
    <#
    .SYNOPSIS
        Creates Dictionary<String,Double> suitable for adding custom metric values and then sending with Events or Exceptions.
        Not suitable for sending standalone metrics - use Write-AiMetric instead
    #>
    Process
    {
        new-object 'System.Collections.Generic.Dictionary[String,Double]'
    }
}

Function New-AiMetadata
{
    <#
    .SYNOPSIS
        Creates Dictionary<String,String> suitable for adding custom metadata and then sending with Events, Traces, Metrics or Exceptions as AdditionalMetadata parameter
    #>
    Process
    {
        new-object 'System.Collections.Generic.Dictionary[String,String]'
    }
}

Function Set-AiOperationContext
{
    <#
    .SYNOPSIS
        Registers operation ID and name to be sent with all telemetry produced after registered - until this command is called without parameters, which unregisters operation ID and name.
        Use ParentId when interested in anylysis of logged chained operations
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
            #Identifier of running operation
        $Id,
        [Parameter()]
        [string]
            #Name of running operation
        $Name,
        [Parameter()]
        [string]
            #Name of parent operation (if any)
            #Useful for logging of chained operations
        $ParentId
    )

    Process
    {
        $script:telemetryClient.Context.Operation.Id = $Id
        $script:telemetryClient.Context.Operation.Name = $Name
        $script:telemetryClient.Context.Operation.ParentId = $ParentId
    }
}

Function Set-AiUserContext
{
    <#
    .SYNOPSIS
        Registers user ID and name to be sent with all telemetry produced after registered - until this command is called without parameters, which unregisters user ID and name.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
            #Identifier of user involved in the operation
        $Id,
        [Parameter()]
        [string]
            #Name of user involved in the operation
        $Name
    )

    Process
    {
        $script:telemetryClient.Context.User.Id = $Id
        $script:telemetryClient.Context.User.AccountId = $Name
    }
}

#region Helpers
function IsInitialized
{
    process
    {
        if($null -eq $script:telemetryClient)
        {
            Write-Warning $MyInvocation.MyCommand.Module.PrivateData['Messages']['NotInitialized'] -Verbose
            return $false
        }
        return $true
    }
}
#endregion


#region ImplicitInitialization for arguments passed to Import-Module
$script:ProtectedMetadata = @()

if(-not ([string]::IsNullOrEmpty($InstrumentationKey) -or [string]::IsNullOrEmpty($Application) -or [string]::IsNullOrEmpty($Component)))
{
    Initialize-AiLogger -InstrumentationKey $InstrumentationKey -Application $Application -Component $Component -Role $Role -Instance $Instance
}

IsInitialized | Out-Null
#endregion