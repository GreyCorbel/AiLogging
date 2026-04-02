#region Public commands
function Add-AiMetadata {
    <#
    .SYNOPSIS
        Adds a metadata entry to a metadata dictionary.

    .DESCRIPTION
        Adds a named metadata value to a dictionary created by New-AiMetadata.
        If the metadata name already exists, the value is only replaced when -Force is used.
        Use -PassThrough to keep the dictionary on the pipeline for chaining.

    .PARAMETER Metadata
        Metadata dictionary created by New-AiMetadata.

    .PARAMETER Name
        Metadata key to add.

    .PARAMETER Value
        Metadata value to add.

    .PARAMETER Force
        Replaces an existing metadata value when the same key is already present.

    .PARAMETER PassThrough
        Returns the updated metadata dictionary so you can continue piping it.

    .EXAMPLE
        New-AiMetadata | Add-AiMetadata -Name 'TenantId' -Value 'contoso' -PassThrough

        Creates a metadata dictionary, adds a key, and emits the updated dictionary.

    .EXAMPLE
        $metadata | Add-AiMetadata -Name 'Environment' -Value 'Prod' -Force

        Replaces the value of an existing metadata key named Environment.
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
        Adds a metric entry to a metrics dictionary.

    .DESCRIPTION
        Adds a named metric value to a dictionary created by New-AiMetric.
        If the metric name already exists, the value is only replaced when -Force is used.
        Use -PassThrough to keep the dictionary on the pipeline for chaining.

    .PARAMETER Metrics
        Metrics dictionary created by New-AiMetric.

    .PARAMETER Name
        Metric name to add.

    .PARAMETER Value
        Metric value to add.

    .PARAMETER Force
        Replaces an existing metric value when the same name is already present.

    .PARAMETER PassThrough
        Returns the updated metrics dictionary so you can continue piping it.

    .EXAMPLE
        New-AiMetric | Add-AiMetric -Name 'ProcessedItems' -Value 42 -PassThrough

        Creates a metrics dictionary, adds a metric, and emits the updated dictionary.

    .EXAMPLE
        $metrics | Add-AiMetric -Name 'DurationMs' -Value 1375 -Force

        Replaces the value of an existing metric named DurationMs.
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
        Creates an Application Insights telemetry connection.

    .DESCRIPTION
        Creates a telemetry client for Application Insights, configures default metadata,
        and stores the client as the most recently created connection used by other commands.
        If -ConnectionString is omitted, the command reads APPLICATIONINSIGHTS_CONNECTION_STRING
        from the current environment.

    .PARAMETER ConnectionString
        Application Insights connection string. When omitted, the command tries to use the
        APPLICATIONINSIGHTS_CONNECTION_STRING environment variable.

    .PARAMETER Application
        Application name added to default telemetry metadata and used when building the metric namespace.

    .PARAMETER Component
        Component name added to default telemetry metadata and used when building the metric namespace.

    .PARAMETER Role
        Optional cloud role name associated with emitted telemetry.

    .PARAMETER Instance
        Optional cloud role instance associated with emitted telemetry.

    .PARAMETER DefaultMetadata
        Additional metadata to attach to every telemetry item sent through the connection.

    .OUTPUTS
        Microsoft.ApplicationInsights.TelemetryClient

    .EXAMPLE
        Connect-AiLogger -Application 'myAutomationAccount' -Component 'MyRunbook'

        Creates a connection using the APPLICATIONINSIGHTS_CONNECTION_STRING environment variable.

    .EXAMPLE
        $metadata = New-AiMetadata -Name 'Environment' -Value 'Prod'
        Connect-AiLogger -ConnectionString $env:APPLICATIONINSIGHTS_CONNECTION_STRING -Application 'Orders' -Component 'Worker' -Role 'HybridWorker' -Instance $env:COMPUTERNAME -DefaultMetadata $metadata

        Creates a connection with explicit role and default metadata.
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
        if($null -ne $script:LastCreatedAiLogger) {$script:LastCreatedAiLogger.TelemetryConfiguration.Dispose()}

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
        Returns the most recently created telemetry connection.

    .DESCRIPTION
        Returns the last connection created by Connect-AiLogger from module scope.
        Use this when you want to inspect or reuse the active telemetry client.

    .OUTPUTS
        Microsoft.ApplicationInsights.TelemetryClient

    .EXAMPLE
        Get-AiConnection

        Returns the active telemetry connection for the current session.
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
        Creates a metadata dictionary.

    .DESCRIPTION
        Creates a System.Collections.Generic.Dictionary[String,String] for telemetry metadata.
        You can optionally seed it with an initial key-value pair and then add more entries with Add-AiMetadata.

    .PARAMETER Name
        Optional initial metadata key.

    .PARAMETER Value
        Optional initial metadata value.

    .OUTPUTS
        System.Collections.Generic.Dictionary[String,String]

    .EXAMPLE
        New-AiMetadata

        Creates an empty metadata dictionary.

    .EXAMPLE
        New-AiMetadata -Name 'TenantId' -Value 'contoso'

        Creates a metadata dictionary with a single initial entry.
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
        Creates a metrics dictionary.

    .DESCRIPTION
        Creates a System.Collections.Generic.Dictionary[String,Double] for metric values.
        You can optionally seed it with an initial metric and then add more entries with Add-AiMetric.

    .PARAMETER Name
        Optional initial metric name.

    .PARAMETER Value
        Optional initial metric value.

    .OUTPUTS
        System.Collections.Generic.Dictionary[String,Double]

    .EXAMPLE
        New-AiMetric

        Creates an empty metrics dictionary.

    .EXAMPLE
        New-AiMetric -Name 'ProcessedItems' -Value 42

        Creates a metrics dictionary with a single initial metric.
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
        Updates default metadata on a telemetry connection.

    .DESCRIPTION
        Updates default metadata for the connection. 
        This metadata is sent with all telemetry items unless overridden by specific metadata.
        Values of any existing default metadata are replaced by the new values.

    .PARAMETER Metadata
        Metadata dictionary whose entries should be merged into the connection defaults.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.

    .EXAMPLE
        New-AiMetadata -Name 'Environment' -Value 'Prod' | Set-AiDefaultMetadata

        Adds or replaces the Environment default metadata entry on the active connection.

    .EXAMPLE
        $metadata | Set-AiDefaultMetadata -Connection $connection

        Applies metadata defaults to a specific connection.
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
            if(-not $connection.TelemetryMetadata.ContainsKey($key))
            {
                Write-Verbose "AiLogger: Adding default metadata $key = $($Metadata[$key])"
            }
            else
            {
                Write-Verbose "AiLogger: Replacing default metadata $key = $($Metadata[$key])"
            }
            $connection.TelemetryMetadata[$key] = $Metadata[$key]
        }
    }
}
Function Submit-AiData
{
    <#
    .SYNOPSIS
        Flushes buffered telemetry to Application Insights.

    .DESCRIPTION
        Flushes any buffered telemetry for the specified connection and waits briefly to allow
        the telemetry channel to send pending data. This is useful in short-lived scripts and runbooks.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.

    .EXAMPLE
        Submit-AiData

        Flushes buffered telemetry for the active connection before the script exits.

    .EXAMPLE
        Submit-AiData -Connection $connection

        Flushes buffered telemetry for a specific connection.
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
        Logs a dependency call to an external service.

    .DESCRIPTION
        Writes dependency telemetry to Application Insights for calls to external systems such as
        HTTP endpoints, SQL databases, or other services. Dependency telemetry can be used by
        Application Insights to populate the Application Map.

    .PARAMETER Target
        Host name or other target identifier for the dependency.

    .PARAMETER DependencyType
        Dependency type such as HTTP, SQL, or FTP.

    .PARAMETER Name
        Operation name for the dependency call.

    .PARAMETER Data
        Optional dependency details such as a URL, stored procedure name, or command text.

    .PARAMETER Start
        Start time of the dependency call.

    .PARAMETER Duration
        Duration of the dependency call. When omitted, the duration is calculated from Start to the current UTC time.

    .PARAMETER ResultCode
        Optional status or result code returned by the dependency.

    .PARAMETER Metrics
        Optional metrics dictionary to include with the dependency telemetry.

    .PARAMETER Success
        Indicates whether the dependency call succeeded.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.

    .EXAMPLE
        $start = Get-Date
        Invoke-WebRequest -Uri $uri | Out-Null
        Write-AiDependency -Target $uri.Host -DependencyType 'HTTP' -Name 'Invoke-WebRequest' -Data $uri.AbsoluteUri -Start $start

        Logs an HTTP dependency and calculates the duration automatically.

    .EXAMPLE
        Write-AiDependency -Target 'sql-prod-01' -DependencyType 'SQL' -Name 'usp_LoadOrders' -Data 'usp_LoadOrders' -Start $start -Duration $duration -ResultCode '0' -Success $true -Connection $connection

        Logs a SQL dependency using an explicit connection and duration.
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
        if($null -eq $Duration) {
            $start = $Start.ToUniversalTime()
            $Duration = (Get-Date -AsUTC) - $Start
        }
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
        Logs an event with optional metadata and metrics.

    .DESCRIPTION
        Writes event telemetry to Application Insights. Use events for important business or workflow
        milestones that may also carry related metadata and numeric measurements.

    .PARAMETER EventName
        Name of the event to record.

    .PARAMETER Metrics
        Optional metrics dictionary to include with the event.

    .PARAMETER Metadata
        Optional metadata dictionary to include with the event.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.

    .EXAMPLE
        Write-AiEvent -EventName 'IngestionStarted'

        Writes a simple event using the active connection.

    .EXAMPLE
        Write-AiEvent -EventName 'IngestionCompleted' -Metadata $metadata -Metrics $metrics -Connection $connection

        Writes an event with additional metadata and metrics.
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
        $Connection.TrackEvent($data)
    }
}
Function Write-AiException
{
    <#
    .SYNOPSIS
        Logs an exception with optional metadata and metrics.

    .DESCRIPTION
        Writes exception telemetry to Application Insights. Use this command inside catch blocks
        to record exceptions together with relevant metadata and measurements.

    .PARAMETER Exception
        Exception instance to record.

    .PARAMETER Metrics
        Optional metrics dictionary to include with the exception telemetry.

    .PARAMETER Metadata
        Optional metadata dictionary to include with the exception telemetry.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.

    .EXAMPLE
        try {
            Invoke-RiskyOperation
        }
        catch {
            $_.Exception | Write-AiException
        }

        Writes the caught exception by using the pipeline.

    .EXAMPLE
        $_.Exception | Write-AiException -Metadata $metadata -Metrics $metrics -Connection $connection

        Writes the exception together with additional context.
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

        Write-Verbose "AiLogger: Writing exception $($Exception.Message)"
        $Connection.TrackException($data)
    }
}
Function Write-AiMetric
{
    <#
    .SYNOPSIS
        Logs metric values with optional metadata.

    .DESCRIPTION
        Writes each metric in a metrics dictionary to Application Insights without local aggregation.
        The metric namespace is taken from the connection created by Connect-AiLogger.

    .PARAMETER Metrics
        Metrics dictionary to write.

    .PARAMETER Metadata
        Optional metadata dictionary to include with every metric written by this call.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.

    .EXAMPLE
        New-AiMetric -Name 'ProcessedItems' -Value 42 | Write-AiMetric

        Writes a single metric by using the active connection.

    .EXAMPLE
        $metrics | Write-AiMetric -Metadata $metadata -Connection $connection

        Writes multiple metrics together with shared metadata.
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
        Writes a trace message with optional severity and metadata.

    .DESCRIPTION
        Writes trace telemetry to Application Insights. Trace messages are useful for operational
        logging and diagnostics. The default severity is Information.

    .PARAMETER Message
        Trace message to record.

    .PARAMETER Severity
        Severity level to associate with the trace. Defaults to Information.

    .PARAMETER Metadata
        Optional metadata dictionary to include with the trace.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.
    
    .EXAMPLE
        Write-AiTrace 'Beginning processing'

        Writes an informational trace by using the active connection.

    .EXAMPLE
        $meta = New-AiMetadata | Add-AiMetadata -Name 'Context' -Value 'MyContext' -PassThrough
        Write-AiTrace -Message "Performed context-specific action" -Metadata $meta

        Writes a trace with custom metadata.

    .EXAMPLE
        Write-AiTrace -Message 'Validation failed' -Severity Warning -Connection $connection

        Writes a warning trace on a specific connection.
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
