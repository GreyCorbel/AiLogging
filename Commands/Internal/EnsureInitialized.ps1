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
            throw 'Please call Connect-AiLogger first'
        }
    }
}