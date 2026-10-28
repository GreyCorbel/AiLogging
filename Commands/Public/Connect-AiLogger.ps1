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