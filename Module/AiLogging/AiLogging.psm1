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
        if($metadata.ContainsKey($Name) -and -not $Force) {
            Write-Warning "Metadata with name $Name already exists. Use -Force to overwrite"
        }
        else {
            $metadata[$Name] = $Value
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
        if($Metrics.ContainsKey($Name) -and -not $Force) {
            Write-Warning "Metric with name $Name already exists. Use -Force to overwrite"
        }
        else {
            $Metrics[$Name] = $Value
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
        Creates a connection to Application Insights, configures default metadata,
        and stores the connection as the most recently created connection used by other commands.
        Telemetry is buffered and sent to Application Insights ingestion REST API.
        If -ConnectionString is omitted, the command reads APPLICATIONINSIGHTS_CONNECTION_STRING
        from the current environment.

        By default, telemetry is authenticated by instrumentation key from connection string.
        When -Factory is specified, each request additionally carries an Entra ID access token
        obtained from the AadAuthenticationFactory module (required when local authentication
        is disabled on Application Insights resource). The identity needs the
        'Monitoring Metrics Publisher' role on the Application Insights resource.

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

    .PARAMETER Factory
        Optional AadAuthenticationFactory instance (created by New-AadAuthenticationFactory) used
        to obtain access tokens. When omitted, instrumentation key authentication is used.

    .PARAMETER Scopes
        Scopes requested from Factory. Defaults to https://monitor.azure.com//.default

    .PARAMETER MaxBatchSize
        Number of buffered telemetry items that triggers sending. Defaults to 500.

    .PARAMETER FlushIntervalSeconds
        Max age of buffered telemetry, checked whenever telemetry is written. Defaults to 30 seconds.
        Use 0 to send every telemetry item immediately.

    .OUTPUTS
        AiLogging.Connection

    .EXAMPLE
        Connect-AiLogger -Application 'myAutomationAccount' -Component 'MyRunbook'

        Creates a connection using the APPLICATIONINSIGHTS_CONNECTION_STRING environment variable.

    .EXAMPLE
        $metadata = New-AiMetadata -Name 'Environment' -Value 'Prod'
        Connect-AiLogger -ConnectionString $env:APPLICATIONINSIGHTS_CONNECTION_STRING -Application 'Orders' -Component 'Worker' -Role 'HybridWorker' -Instance $env:COMPUTERNAME -DefaultMetadata $metadata

        Creates a connection with explicit role and default metadata.

    .EXAMPLE
        $factory = New-AadAuthenticationFactory -UseManagedIdentity
        Connect-AiLogger -Application 'Orders' -Component 'Worker' -Factory $factory

        Creates a connection that authenticates telemetry with access token of managed identity.
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
        $DefaultMetadata,
        [Parameter()]
            #AadAuthenticationFactory instance (or name) used to obtain access tokens for ingestion
            #When not specified, instrumentation key authentication is used
        $Factory,
        [Parameter()]
        [string[]]
            #Scopes requested when obtaining access token from Factory
        $Scopes = @('https://monitor.azure.com//.default'),
        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]
            #Max number of telemetry items buffered before they are sent
        $MaxBatchSize = 500,
        [Parameter()]
        [ValidateRange(0, 3600)]
        [int]
            #Max age in seconds of buffered telemetry; checked when new telemetry is written
            #0 means that every telemetry item is sent immediately
        $FlushIntervalSeconds = 30
    )

    process
    {
        #deliver anything still buffered on previous connection
        if($null -ne $script:LastCreatedAiLogger) { Send-AiTelemetry -Connection $script:LastCreatedAiLogger }

        if([string]::IsNullOrEmpty($ConnectionString))
        {
            #try to load connection string from environment variable
            $ConnectionString = $env:APPLICATIONINSIGHTS_CONNECTION_STRING
        }
        if([string]::IsNullOrEmpty($ConnectionString))
        {
            Write-Warning 'Connection string was not provided and no environment variable APPLICATIONINSIGHTS_CONNECTION_STRING was found'
            $ConnectionString = ''
        }
        $parsed = ConvertFrom-AiConnectionString -ConnectionString $ConnectionString
        $script:AiSdkVersion = "ailogging-ps:$($MyInvocation.MyCommand.Module.Version)"

        if($null -ne $Factory -and $null -eq (Get-Command Get-AadToken -ErrorAction SilentlyContinue))
        {
            throw 'AadAuthenticationFactory module is required for token based authentication. Install it via Install-Module AadAuthenticationFactory'
        }

        #setup base metadata
        $metadata = New-Object 'System.Collections.Generic.Dictionary[String,String]'
        $metadata['Application'] = $Application
        $metadata['Component'] = $Component
        if($null -ne $DefaultMetadata)
        {
            foreach($key in $DefaultMetadata.Keys)
            {
                if(-not $metadata.ContainsKey($key)) { $metadata[$key] = $DefaultMetadata[$key] }
            }
        }

        $connection = [PSCustomObject]@{
            PSTypeName = 'AiLogging.Connection'
            InstrumentationKey = $parsed.InstrumentationKey
            IngestionEndpoint = $parsed.IngestionEndpoint
            TrackUri = "$($parsed.IngestionEndpoint)/v2.1/track"
            AuthenticationFactory = $Factory
            Scopes = $Scopes
            TelemetryMetadata = $metadata
            MetricNamespace = "$Application`.$Component"
            RoleName = $(if([string]::IsNullOrEmpty($Role)) {"$Application`.$Component"} else {$Role})
            RoleInstance = $(if([string]::IsNullOrEmpty($Instance)) {[Environment]::MachineName} else {$Instance})
            MaxBatchSize = $MaxBatchSize
            FlushInterval = [TimeSpan]::FromSeconds($FlushIntervalSeconds)
            LastFlush = [DateTime]::UtcNow
            Buffer = New-Object 'System.Collections.Generic.List[object]'
        }

        $script:LastCreatedAiLogger = $connection
        Write-Verbose ( ($ConnectionString.Split(';') | Where-Object{$_ -notlike 'InstrumentationKey=*'}) -join ';')
        Write-Verbose "AiLogger: Authentication: $(if($null -ne $Factory) {'access token'} else {'instrumentation key'})"
        $connection
    }
}
function Get-AiConnection {
    <#
    .SYNOPSIS
        Returns the most recently created telemetry connection.

    .DESCRIPTION
        Returns the last connection created by Connect-AiLogger from module scope.
        Use this when you want to inspect or reuse the active telemetry connection.

    .OUTPUTS
        AiLogging.Connection

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
        Sends any buffered telemetry for the specified connection to Application Insights
        and waits for the send to complete. Call this before short-lived scripts and runbooks exit.

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
        Send-AiTelemetry -Connection $Connection
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
        if(-not $PSBoundParameters.ContainsKey('Duration')) {
            $Duration = ([DateTime]::UtcNow) - $Start.ToUniversalTime()
        }
        $baseData = [ordered]@{
            id = [Guid]::NewGuid().ToString('N').Substring(0, 16)
            name = $Name
            type = $DependencyType
            target = $Target
            data = $Data
            duration = $Duration.ToString('c', [System.Globalization.CultureInfo]::InvariantCulture)
            success = $Success
        }
        if(-not [string]::IsNullOrEmpty($ResultCode)) {
            $baseData['resultCode'] = $ResultCode
        }
        if($null -ne $Metrics) {
            $baseData['measurements'] = $Metrics
        }
        $envelope = New-AiEnvelope -Connection $Connection -TelemetryType RemoteDependency -BaseData $baseData -Timestamp $Start

        Write-Verbose "Writing dependency: Name = $Name, Type = $DependencyType, Start = $Start, Duration = $Duration, Success = $Success,  Target = $Target, Data = $Data"
        Add-AiTelemetry -Connection $Connection -Envelope $envelope
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
        $baseData = [ordered]@{ name = $EventName }
        if($null -ne $Metrics) { $baseData['measurements'] = $Metrics }
        $envelope = New-AiEnvelope -Connection $Connection -TelemetryType Event -BaseData $baseData -Metadata $Metadata

        Write-Verbose "AiLogger: Writing event $EventName"
        Add-AiTelemetry -Connection $Connection -Envelope $envelope
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
        $exceptions = New-Object System.Collections.Generic.List[object]
        $current = $Exception
        $outerId = 0
        while($null -ne $current)
        {
            $id = $current.GetHashCode()
            $stack = "$($current.StackTrace)"
            $exceptions.Add([ordered]@{
                id = $id
                outerId = $outerId
                typeName = $current.GetType().FullName
                message = "$($current.Message)"
                hasFullStack = $true
                stack = $stack.Substring(0, [Math]::Min($stack.Length, 32768))
            })
            $outerId = $id
            $current = $current.InnerException
        }
        $baseData = [ordered]@{
            exceptions = $exceptions.ToArray()
            severityLevel = 'Error'
        }
        if($null -ne $Metrics) { $baseData['measurements'] = $Metrics }
        $envelope = New-AiEnvelope -Connection $Connection -TelemetryType Exception -BaseData $baseData -Metadata $Metadata

        Write-Verbose "AiLogger: Writing exception $($Exception.Message)"
        Add-AiTelemetry -Connection $Connection -Envelope $envelope
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
            $baseData = [ordered]@{
                metrics = @(
                    [ordered]@{
                        ns = $Connection.MetricNamespace
                        name = $metricKey
                        kind = 0
                        value = $Metrics[$metricKey]
                        count = 1
                    }
                )
            }
            $envelope = New-AiEnvelope -Connection $Connection -TelemetryType Metric -BaseData $baseData -Metadata $Metadata

            Write-Verbose "AiLogger: Writing metric $metricKey = $($metrics[$metricKey])"
            Add-AiTelemetry -Connection $Connection -Envelope $envelope
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
        [ValidateSet('Verbose','Information','Warning','Error','Critical')]
        [string]
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
        $baseData = [ordered]@{
            message = $Message
            severityLevel = $Severity
        }
        $envelope = New-AiEnvelope -Connection $Connection -TelemetryType Message -BaseData $baseData -Metadata $Metadata

        Write-Verbose "AiLogger: Writing trace $Severity`: $Message"
        Add-AiTelemetry -Connection $Connection -Envelope $envelope
    }
}
#endregion Public commands
#region Internal commands
function Add-AiTelemetry
{
    param
    (
        [Parameter(Mandatory)]
        $Connection,
        [Parameter(Mandatory)]
        $Envelope
    )

    process
    {
        if($null -eq $Connection)
        {
            Write-Warning 'AiLogger: No connection available. Call Connect-AiLogger first.'
            return
        }
        $Connection.Buffer.Add($Envelope)
        if($Connection.Buffer.Count -ge $Connection.MaxBatchSize -or ([DateTime]::UtcNow - $Connection.LastFlush) -ge $Connection.FlushInterval)
        {
            Send-AiTelemetry -Connection $Connection
        }
    }
}
function ConvertFrom-AiConnectionString
{
    param
    (
        [Parameter(Mandatory)]
        [string]$ConnectionString
    )

    process
    {
        $parts = @{}
        foreach($segment in $ConnectionString.Split(';', [StringSplitOptions]::RemoveEmptyEntries))
        {
            $idx = $segment.IndexOf('=')
            if($idx -lt 1) { continue }
            $parts[$segment.Substring(0, $idx).Trim()] = $segment.Substring($idx + 1).Trim()
        }

        $endpoint = $parts['IngestionEndpoint']
        if([string]::IsNullOrEmpty($endpoint))
        {
            if(-not [string]::IsNullOrEmpty($parts['EndpointSuffix']))
            {
                $prefix = if([string]::IsNullOrEmpty($parts['Location'])) {''} else {"$($parts['Location'])."}
                $endpoint = "https://$($prefix)dc.$($parts['EndpointSuffix'])"
            }
            else
            {
                $endpoint = 'https://dc.services.visualstudio.com'
            }
        }

        [PSCustomObject]@{
            InstrumentationKey = $parts['InstrumentationKey']
            IngestionEndpoint = $endpoint.TrimEnd('/')
        }
    }
}
function Get-AiAuthorizationHeader
{
    param
    (
        [Parameter(Mandatory)]
        $Connection
    )

    process
    {
        if($null -eq $Connection.AuthenticationFactory) { return }
        #factory caches and refreshes tokens as needed
        $header = Get-AadToken -Factory $Connection.AuthenticationFactory -Scopes $Connection.Scopes -AsHashTable -ErrorAction Stop
        $header['Authorization']
    }
}
function Init
{
    Add-Type -AssemblyName System.Net.Http
    if($PSVersionTable.PSEdition -ne 'Core')
    {
        #Windows PowerShell on older .NET Framework may not offer TLS 1.2 by default, which ingestion endpoints require
        $protocol = [Net.ServicePointManager]::SecurityProtocol
        if([int]$protocol -ne 0 -and -not ($protocol -band [Net.SecurityProtocolType]::Tls12))
        {
            [Net.ServicePointManager]::SecurityProtocol = $protocol -bor [Net.SecurityProtocolType]::Tls12
        }
    }
    $script:AiHttpClient = [System.Net.Http.HttpClient]::new()
    $script:AiHttpClient.Timeout = [TimeSpan]::FromSeconds(30)

    #try to deliver buffered telemetry when module is removed
    $ExecutionContext.SessionState.Module.OnRemove = {
        if($null -ne $script:LastCreatedAiLogger) { Send-AiTelemetry -Connection $script:LastCreatedAiLogger }
        $script:AiHttpClient.Dispose()
    }
}
function New-AiEnvelope
{
    param
    (
        [Parameter(Mandatory)]
        $Connection,
        [Parameter(Mandatory)]
        [ValidateSet('Event','Message','Metric','RemoteDependency','Exception')]
        [string]$TelemetryType,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$BaseData,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]$Metadata,
        [Parameter()]
        [DateTime]$Timestamp = [DateTime]::UtcNow
    )

    process
    {
        #default metadata first, then call-specific metadata overrides it
        $properties = @{}
        foreach($key in $Connection.TelemetryMetadata.Keys) { $properties[$key] = $Connection.TelemetryMetadata[$key] }
        if($null -ne $Metadata)
        {
            foreach($key in $Metadata.Keys) { $properties[$key] = $Metadata[$key] }
        }
        $BaseData['ver'] = 2
        $BaseData['properties'] = $properties

        $tags = [ordered]@{
            'ai.internal.sdkVersion' = $script:AiSdkVersion
        }
        if(-not [string]::IsNullOrEmpty($Connection.RoleName)) { $tags['ai.cloud.role'] = $Connection.RoleName }
        if(-not [string]::IsNullOrEmpty($Connection.RoleInstance)) { $tags['ai.cloud.roleInstance'] = $Connection.RoleInstance }

        $iKeyNoDashes = "$($Connection.InstrumentationKey)".Replace('-', '')
        [ordered]@{
            name = "Microsoft.ApplicationInsights.$iKeyNoDashes.$TelemetryType"
            time = $Timestamp.ToUniversalTime().ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
            iKey = $Connection.InstrumentationKey
            tags = $tags
            data = [ordered]@{
                baseType = "$($TelemetryType)Data"
                baseData = $BaseData
            }
        }
    }
}
function Send-AiTelemetry
{
    param
    (
        [Parameter(Mandatory)]
        $Connection
    )

    process
    {
        $Connection.LastFlush = [DateTime]::UtcNow
        if($Connection.Buffer.Count -eq 0) { return }

        $pending = $Connection.Buffer.ToArray()
        $Connection.Buffer.Clear()

        if([string]::IsNullOrEmpty($Connection.InstrumentationKey))
        {
            Write-Verbose "AiLogger: No instrumentation key configured, discarding $($pending.Count) telemetry item(s)"
            return
        }

        $retriableCodes = @(408, 429, 439, 500, 502, 503, 504)
        $maxAttempts = 3
        for($attempt = 1; $attempt -le $maxAttempts; $attempt++)
        {
            $statusCode = 0
            $responseBody = $null
            try
            {
                $json = ConvertTo-Json -InputObject @($pending) -Depth 10 -Compress
                $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $Connection.TrackUri)
                $request.Content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
                $authHeader = Get-AiAuthorizationHeader -Connection $Connection
                if(-not [string]::IsNullOrEmpty($authHeader))
                {
                    [void]$request.Headers.TryAddWithoutValidation('Authorization', $authHeader)
                }
                Write-Verbose "AiLogger: Sending $($pending.Count) telemetry item(s) to $($Connection.TrackUri) (attempt $attempt)"
                $response = $script:AiHttpClient.SendAsync($request).GetAwaiter().GetResult()
                $statusCode = [int]$response.StatusCode
                $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                $response.Dispose()
                $request.Dispose()
            }
            catch
            {
                Write-Verbose "AiLogger: Sending telemetry failed: $($_.Exception.Message)"
            }

            switch($statusCode)
            {
                200 {
                    return
                }
                206 {
                    $result = $responseBody | ConvertFrom-Json
                    $retry = new-object System.Collections.Generic.List[object]
                    foreach($err in $result.errors)
                    {
                        if($err.statusCode -in $retriableCodes) {
                            $retry.Add($pending[$err.index])
                        }
                        else {
                            Write-Warning "AiLogger: Telemetry item rejected: $($err.statusCode) $($err.message)"
                        }
                    }
                    if($retry.Count -eq 0) { return }
                    $pending = $retry.ToArray()
                    break
                }
                {$_ -in 401, 403} {
                    Write-Warning "AiLogger: Telemetry rejected with status $statusCode (authentication/authorization failure): $responseBody"
                    return
                }
                {$_ -eq 0 -or $_ -in $retriableCodes} {
                    Write-Verbose "AiLogger: Transient failure (status $statusCode)"
                    break
                }
                default {
                    Write-Warning "AiLogger: Telemetry rejected with status $statusCode`: $responseBody"
                    return
                }
            }
            if($attempt -lt $maxAttempts) { Start-Sleep -Seconds ([Math]::Pow(2, $attempt - 1)) }
        }
        Write-Warning "AiLogger: Failed to send $($pending.Count) telemetry item(s) after $maxAttempts attempts"
    }
}
#endregion Internal commands
#region Module initialization
Init
#endregion Module initialization
