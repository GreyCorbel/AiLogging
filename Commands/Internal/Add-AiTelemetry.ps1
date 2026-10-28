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
