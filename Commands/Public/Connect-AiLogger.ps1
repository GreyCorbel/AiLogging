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