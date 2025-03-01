function EnsureInitialized
{
    param
    (
        [Parameter()]
        $Connection
    )
    process
    {
        if($null -eq $Connection)
        {
            Write-Verbose "No connection provided, will not log telemetry"
            return $false
        }
        return $true
    }
}