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
