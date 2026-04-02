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
