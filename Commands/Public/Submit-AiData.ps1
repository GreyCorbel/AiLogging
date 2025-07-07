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
