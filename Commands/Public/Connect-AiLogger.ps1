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
        if($null -ne $script:LastCreatedAiLogger) {$script.$script:LastCreatedAiLogger.Dispose()}

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