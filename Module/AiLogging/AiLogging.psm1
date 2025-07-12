#region Public commands
function Add-AiMetadata {
    <#
    .SYNOPSIS
        Adds new metadata to provided metadata collection
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
        [switch]
            #allows rewrite of already present metadata
        $Force,
        [switch]
            #causes input object to be passed to output, enabling chaining
        $PassThrough
    )
    
    process {
        if(-not $metadata.TryAdd($Name, $Value) ) {
            if($Force) {
                $metadata[$Name] = $Value
            } else {
                Write-Warning "Metadata with name $Name already exists. Use -Force to overwrite"
            }
        }
        if($PassThrough) {
            $metadata
        }
    }
}
function Add-AiMetric {
    <#
    .SYNOPSIS
        Adds new metric to provided metrics collection
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Metrics collection created by New-AiMetric
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
        [switch]
            #allows rewrite of already present metrics
        $Force,
        [switch]
            #causes input object to be passed to output, enabling chaining
        $PassThrough
    )
    
    process {
        if(-not $Metrics.TryAdd($Name, $Value)) {
            if($Force) {
                $Metrics[$Name] = $Value
            } else {
                Write-Warning "Metric with name $Name already exists. Use -Force to overwrite"
            }
        }
        if($PassThrough) {
            $Metrics
        }
    }
}
function Connect-AiLogger
{
    <#
    .SYNOPSIS
        Creates connection to Application Insights and sets up metadata for all logs sent with this connection
    .DESCRIPTION
        Creates connection to Application Insights and sets up metadata for all logs sent with this connection
    #>
    param
    (
        [Parameter()]
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
        $Instance,
        [System.Collections.Generic.Dictionary[String,String]]
        #Additional metadata to be added to each emited telemetry
        $DefaultMetadata

    )

    begin
    {

    }
    process
    {
        if($null -ne $script:LastCreatedAiLogger) {$script:LastCreatedAiLogger.Dispose()}

        $config = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::CreateDefault()
        if([string]::IsNullOrEmpty($ConnectionString))
        {
            #try to load connection string from environment variable
            $ConnectionString = $env:APPLICATIONINSIGHTS_CONNECTION_STRING
        }
        if([string]::IsNullOrEmpty($ConnectionString))
        {
            Write-Warning 'Connection string was not provided and no environment variable APPLICATIONINSIGHTS_CONNECTION_STRING was found'
        }
        else {
            $config.ConnectionString = $ConnectionString
        }
        
        #setup base metadata
        $client = new-object Microsoft.ApplicationInsights.TelemetryClient($config)
        $client | Add-Member -MemberType NoteProperty -Name TelemetryMetadata -Value (New-Object 'System.Collections.Generic.Dictionary[String,String]')
        $client.telemetryMetadata['Application']=$Application
        $client.telemetryMetadata['Component']=$Component
        if($null -ne $DefaultMetadata)
        {
            foreach($key in $DefaultMetadata.Keys)
            {
                $client.telemetryMetadata.TryAdd($key, $DefaultMetadata[$key]) | Out-Null
            }
        }

        #setup metrics
        $client | Add-Member -MemberType NoteProperty -Name MetricNamespace -Value "$Application`.$Component"

        #setup rolename and roleInstance
        $telemetryInitializer = new-object CloudRoleNameTelemetryInitializer($Role, $Instance)

        $config.TelemetryInitializers.Add($telemetryInitializer) | Out-Null
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
        Write-Verbose ( ($ConnectionString.Split(';') | Where-Object{$_ -notlike 'InstrumentationKey=*'}) -join ';')
        $client
    }
}
function Get-AiConnection {
    <#
    .SYNOPSIS
        Returns most recently created Application Insights connection
    #>
    [CmdletBinding()]
    param ()
    
    process {
        $script:LastCreatedAiLogger
    }
}
Function New-AiMetadata
{
    <#
    .SYNOPSIS
        Creates new metadata collection to be used with Add-AiMetadata
    #>
    param 
    (
        [Parameter()]
        [string]
            #Name of the metric
        $Name,
        [Parameter()]
        [string]
            #Value of the metric
        $Value
    )

    Process
    {
        $metadata = new-object 'System.Collections.Generic.Dictionary[String,String]'
        if(-not [string]::IsNullOrEmpty($Name)) {$metadata[$Name] = $Value}
        return $metadata
    }
}
Function New-AiMetric
{
    <#
    .SYNOPSIS
        Creates new metrics collection to be used with Add-AiMetric
    #>
    param 
    (
        [Parameter()]
        [string]
            #Name of the metric
        $Name,
        [Parameter()]
        [double]
            #Value of the metric
        $Value
    )
    Process
    {
        $metric = new-object 'System.Collections.Generic.Dictionary[String,Double]'
        if(-not [string]::IsNullOrEmpty($Name)) {$metric[$Name] = $Value}
        return $metric
    }
}
Function Set-AiDefaultMetadata
{
    <#
    .SYNOPSIS
        Updates default metadata for the connection, replacing value of any existing metadata
    .DESCRIPTION
        Updates default metadata for the connection. 
        This metadata is sent with all telemetry items unless overridden by specific metadata.
        Values of any existing default metadata are replaced by the new values.
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with metric
        $Metadata,
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger
    )
    begin
    {

    }
    Process
    {   
        foreach($key in $Metadata.Keys)
        {
            Write-Verbose "AiLogger: Setting default metadata $key = $($Metadata[$key])"
            $client.telemetryMetadata[$key] = $Metadata[$key] | Out-Null
        }
    }
}
Function Submit-AiData
{
    <#
    .SYNOPSIS
        Flushes buffered data to Application Insights.
    #>
    param (
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger
    )
    Process
    {   
        Write-Verbose "AiLogger: Flushing buffered data to Application Insights"
        $Connection.Flush()
        Start-Sleep -Seconds 1 # Allow time for flush to complete
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
            # must be in UTC
        $Start,
        [Parameter()]
        [TimeSpan]
            #Duration of the call
            #Default: (current time in UTC) - Start
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

    }
    Process
    {   
        if($null -eq $Duration) {$Duration = (Get-Date -AsUTC) - $Start}
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
        Write-Verbose "Writing dependency: Name = $Name, Type = $DependencyType, Start = $start, Duration = $Duration, Success = $Success,  Target = $Target, Data = $Data"
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

        Write-Verbose "AiLogger: Writing event $EventName"
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

        Write-Verbose "AiLogger: Writing exteption $Exception.Message"
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
        [Parameter(Mandatory, ValueFromPipeline)]
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

    }
    Process
    {   
        foreach($metricKey in $metrics.Keys)
        {
            $data = new-object Microsoft.ApplicationInsights.DataContracts.MetricTelemetry($metricKey, $Metrics[$metricKey])
            $data.MetricNamespace = $Connection.MetricNamespace

            if($null -ne $Metadata) {
                foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
            }
            foreach($key in $Connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $Connection.telemetryMetadata[$key]}

            Write-Verbose "AiLogger: Writing metric $metricKey = $($metrics[$metricKey])"
            $Connection.TrackMetric($data)
        }
    }
}
Function Write-AiTrace
{
    <#
    .SYNOPSIS
        Writes trace message with severity and optional custom metadata.
        Default severity level is Information
    
    .EXAMPLE
        Write-AiTrace 'Beginning processing'

    .EXAMPLE
        $meta = New-AiMetadata | Add-AiMetadata -Name 'Context' -Value 'MyContext' -PassThrough
        Write-AiTrace -Message "Performed context-specific action" -Metadata $meta
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

    }
    Process
    {   
        $data = new-object Microsoft.ApplicationInsights.DataContracts.TraceTelemetry($Message, $Severity)
        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        foreach($key in $connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $connection.telemetryMetadata[$key]}

        Write-Verbose "AiLogger: Writing trace $Severity`: $Message"
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
            Write-Verbose "AiLogger: No connection provided, will not log telemetry"
            return $false
        }
        return $true
    }
}
function Init
{
    Add-Type -AssemblyName Microsoft.ApplicationInsights

    $typeData = Get-Content -Path $PSScriptRoot\Helpers\CloudRoleNameTelemetryInitializer.cs -Raw
    Add-Type -TypeDefinition $typeData -ReferencedAssemblies Microsoft.ApplicationInsights
}
#endregion Internal commands
#region Module initialization
Init
#endregion Module initialization
