function New-AiEnvelope
{
    param
    (
        [Parameter(Mandatory)]
        $Connection,
        [Parameter(Mandatory)]
        [ValidateSet('Event','Message','Metric','RemoteDependency','Exception')]
        [string]$TelemetryType,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$BaseData,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]$Metadata,
        [Parameter()]
        [DateTime]$Timestamp = [DateTime]::UtcNow
    )

    process
    {
        #default metadata first, then call-specific metadata overrides it
        $properties = @{}
        foreach($key in $Connection.TelemetryMetadata.Keys) { $properties[$key] = $Connection.TelemetryMetadata[$key] }
        if($null -ne $Metadata)
        {
            foreach($key in $Metadata.Keys) { $properties[$key] = $Metadata[$key] }
        }
        $BaseData['ver'] = 2
        $BaseData['properties'] = $properties

        $tags = [ordered]@{
            'ai.internal.sdkVersion' = $script:AiSdkVersion
        }
        if(-not [string]::IsNullOrEmpty($Connection.RoleName)) { $tags['ai.cloud.role'] = $Connection.RoleName }
        if(-not [string]::IsNullOrEmpty($Connection.RoleInstance)) { $tags['ai.cloud.roleInstance'] = $Connection.RoleInstance }

        $iKeyNoDashes = "$($Connection.InstrumentationKey)".Replace('-', '')
        [ordered]@{
            name = "Microsoft.ApplicationInsights.$iKeyNoDashes.$TelemetryType"
            time = $Timestamp.ToUniversalTime().ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
            iKey = $Connection.InstrumentationKey
            tags = $tags
            data = [ordered]@{
                baseType = "$($TelemetryType)Data"
                baseData = $BaseData
            }
        }
    }
}
