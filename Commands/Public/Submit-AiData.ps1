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
