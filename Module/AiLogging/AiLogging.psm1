#region Public commands
function Add-AiMetadata {
    <#
    .SYNOPSIS
        Registers additional metadata to be sent with all telemetry produced after registered - until removed by call of Remove-AiMetadata or Reset-AiMetadata
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [System.Collections.Generic.Dictionary[String,String]]
            #Metadata object created by New-AiMetadata
        $Metadata,

        [Parameter(Mandatory)]
        [string]
            #Name of metadata to be registered. Will become custom dimension of telemetry data
            #Allows for easy searching/filtering in ApplicationInsights logs
        $Name,

        [Parameter(Mandatory)]
        [string]
            #Value of metadata
        $Value,
        [switch]$PassThrough
    )
    
    process {
        $metadata.Add($Name, $Value) | Out-Null
        if($PassThrough) {
            $metadata
        }
    }
}
function Add-AiMetric {
    <#
    .SYNOPSIS
        Registers additional metadata to be sent with all telemetry produced after registered - until removed by call of Remove-AiMetadata or Reset-AiMetadata
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Metadata object created by New-AiMetric
        $Metrics,

        [Parameter(Mandatory)]
        [string]
            #Name of metadata to be registered. Will become custom dimension of telemetry data
            #Allows for easy searching/filtering in ApplicationInsights logs
        $Name,

        [Parameter(Mandatory)]
        [string]
            #Value of metadata
        $Value,
        [switch]$PassThrough
    )
    
    process {
        $Metrics.Add($Name, $Value) | Out-Null
        if($PassThrough) {
            $Metrics
        }
    }
}
function Connect-AiLogger
{
    param
    (
        [Parameter(Mandatory)]
        [string]
            #AppInsights connection string
        $ConnectionString,
        [Parameter(Mandatory)]
        [String]
            #Name of the application that is producing the logs
            #For automation accounts, it can be name of automation account
            #Is automatically registered to metadata sent with every piece data logged
        $Application,
        [Parameter(Mandatory)]
        [String]
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

    begin
    {

    }
    process
    {
        add-type -AssemblyName Microsoft.ApplicationInsights
        $config = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::CreateDefault()
        $config.ConnectionString = $ConnectionString
        #setup base metadata
        $client = new-object Microsoft.ApplicationInsights.TelemetryClient($config)
        $client | Add-Member -MemberType NoteProperty -Name TelemetryMetadata -Value (New-Object 'System.Collections.Generic.Dictionary[String,String]')
        $client.telemetryMetadata['Application']=$Application
        $client.telemetryMetadata['Component']=$Component

        #setup metrics
        $client | Add-Member -MemberType NoteProperty -Name MetricNamespace -Value "$Application`.$Component"
        if(-not [string]::IsNullOrEmpty($Role))
        {
            $client.Context.Cloud.RoleName=$Role
        }
        else {
            $client.Context.Cloud.RoleName = "$Application`.$Component"
        }    
        if(-not [string]::IsNullOrEmpty($Instance)) {
            $client.Context.Cloud.RoleInstance = $Instance
        }
        $script:LastCreatedAiLogger = $client
        $client
    }
}
Function New-AiMetadata
{
    <#
    .SYNOPSIS
        Creates Dictionary<String,String> suitable for adding custom metadata and then sending with Events, Traces, Metrics or Exceptions as Metadata parameter
    #>
    Process
    {
        new-object 'System.Collections.Generic.Dictionary[String,String]'
    }
}
Function New-AiMetric
{
    <#
    .SYNOPSIS
        Creates Dictionary<String,Double> suitable for adding custom metric values and then sending with Events or Exceptions as Metrics parameter
        Not suitable for sending standalone metrics - use Write-AiMetric instead
    #>
    Process
    {
        new-object 'System.Collections.Generic.Dictionary[String,Double]'
    }
}
function Write-AiDependency
{
    <#
    .SYNOPSIS
        Logs a call to external service
        Logged call is used by Application Insights to populate Application Map blade
    #>
    param
    (
        [Parameter(Mandatory)]
        [string]
            #Name of endpoint (hostname or host identifier for server being called)
        $Target,
        [Parameter(Mandatory)]
        [string]
            #Name of the dependency type, such as FTP, SQL or HTTP
        $DependencyType,
        [Parameter(Mandatory)]
        [string]
            #Name of the dependency, such as FileDownload, StoredProcedureCall
        $Name,
        [Parameter()]
        [string]
            #Dependency details, such as name of SQL stored procedure, or complete URL requested via HTTP
        $Data,
        [Parameter(Mandatory)]
        [DateTime]
            #When the call started
        $Start,
        [Parameter()]
        [TimeSpan]
            #Duration of the call
            #Default: current time - Start
        $Duration,
        [Parameter()]
        [string]
            #Result code returned by the service
        $ResultCode=$null,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Optional metrics to be sent with the dependency data
        $Metrics=$null,
        [Parameter()]
        [bool]
            #Whether or not call was successful
        $Success = $true,
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger
    )
    begin
    {
        EnsureInitialized -Connection $Connection
    }

    process
    {
        if($null -eq $Duration) {$Duration = (Get-Date) - $Start}
        $dependencyData = new-object Microsoft.ApplicationInsights.DataContracts.DependencyTelemetry
        foreach($key in $Connection.telemetryMetadata.Keys) {$dependencyData.Properties[$Key] = $Connection.telemetryMetadata[$key]}
        $dependencyData.Type=$DependencyType
        $dependencyData.Name=$Name
        $dependencyData.Timestamp=$Start
        $dependencyData.Duration = $Duration
        $dependencyData.Success = $Success
        $dependencyData.Target = $Target
        $dependencyData.Data = $Data
        if($null -ne $ResultCode) {
            $dependencyData.ResultCode = $ResultCode
        }
        if($null -ne $Metrics) {
            foreach($key in $Metrics.Keys) {
                $dependencyData.Metrics[$Key] = $Metrics[$key]
            }
        }

        $Connection.TrackDependency($dependencyData)
    }
}
Function Write-AiEvent
{
    <#
    .SYNOPSIS
        Traces event along with optional custom metadata and metrics.
        Usable when logging additional metrics associated with/related to the event that is not suitable to be logged standalone
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
        $Metadata=$null,
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger
    )
    begin
    {
        EnsureInitialized -Connection $Connection
    }
    Process
    {
        $data = new-object Microsoft.ApplicationInsights.DataContracts.EventTelemetry($EventName)

        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        if($null -ne $Metrics) {
            foreach($key in $Metrics.Keys) {$data.Metrics[$Key] = $Metrics[$key]}
        }
        foreach($key in $Connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $Connection.telemetryMetadata[$key]}
        $Connection.telemetryClient.TrackEvent($data)
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
        $Metadata=$null,
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger
    )
    begin
    {
        EnsureInitialized -Connection $Connection
    }

    Process
    {
        $data = new-object Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry($Exception)
        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        if($null -ne $Metrics) {
            foreach($key in $Metrics.Keys) {$data.Metrics[$Key] = $Metrics[$key]}
        }
        foreach($key in $Connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $Connection.telemetryMetadata[$key]}
        $Connection.TrackException($data)
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
        [System.Collections.Generic.Dictionary[String,Double]]
            #Values of metrics to be sent
        $Metrics,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with metric
        $Metadata=$null,
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger
    )
    begin
    {
        EnsureInitialized -Connection $Connection
    }
    
    Process
    {
        foreach($key in $metrics.Keys)
        {
            $data = new-object Microsoft.ApplicationInsights.DataContracts.MetricTelemetry($key, $Metrics[$key])
            $data.MetricNamespace = $Connection.MetricNamespace

            if($null -ne $Metadata) {
                foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
            }
            foreach($key in $Connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $Connection.telemetryMetadata[$key]}

            $Connection.TrackMetric($data)
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
        $Severity='Information',
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with trace
        $Metadata=$null,
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger
    )
    begin
    {
        EnsureInitialized -Connection $Connection
    }
    Process
    {
        $data = new-object Microsoft.ApplicationInsights.DataContracts.TraceTelemetry($Message, $Severity)
        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        foreach($key in $connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $connection.telemetryMetadata[$key]}

        $connection.TrackTrace($data)
    }
}
#endregion Public commands
#region Internal commands
function EnsureInitialized
{
    param
    (
        [Parameter()]
        $Connection
    )
    process
    {
        if($null -eq $Connection)
        {
            throw 'Please call Connect-AiLogger first'
        }
    }
}
#endregion Internal commands
