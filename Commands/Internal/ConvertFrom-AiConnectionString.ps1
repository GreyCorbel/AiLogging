function ConvertFrom-AiConnectionString
{
    param
    (
        [Parameter(Mandatory)]
        [string]$ConnectionString
    )

    process
    {
        $parts = @{}
        foreach($segment in $ConnectionString.Split(';', [StringSplitOptions]::RemoveEmptyEntries))
        {
            $idx = $segment.IndexOf('=')
            if($idx -lt 1) { continue }
            $parts[$segment.Substring(0, $idx).Trim()] = $segment.Substring($idx + 1).Trim()
        }

        $endpoint = $parts['IngestionEndpoint']
        if([string]::IsNullOrEmpty($endpoint))
        {
            if(-not [string]::IsNullOrEmpty($parts['EndpointSuffix']))
            {
                $prefix = if([string]::IsNullOrEmpty($parts['Location'])) {''} else {"$($parts['Location'])."}
                $endpoint = "https://$($prefix)dc.$($parts['EndpointSuffix'])"
            }
            else
            {
                $endpoint = 'https://dc.services.visualstudio.com'
            }
        }

        [PSCustomObject]@{
            InstrumentationKey = $parts['InstrumentationKey']
            IngestionEndpoint = $endpoint.TrimEnd('/')
        }
    }
}
