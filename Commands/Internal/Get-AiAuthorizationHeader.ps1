function Get-AiAuthorizationHeader
{
    param
    (
        [Parameter(Mandatory)]
        $Connection
    )

    process
    {
        if($null -eq $Connection.AuthenticationFactory) { return }
        #factory caches and refreshes tokens as needed
        $header = Get-AadToken -Factory $Connection.AuthenticationFactory -Scopes $Connection.Scopes -AsHashTable -ErrorAction Stop
        $header['Authorization']
    }
}
