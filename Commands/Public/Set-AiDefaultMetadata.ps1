Function Set-AiDefaultMetadata
{
    <#
    .SYNOPSIS
        Updates default metadata for the connection, replacing value of any existing metadata
    .DESCRIPTION
        Updates default metadata for the connection. 
        This metadata is sent with all telemetry items unless overridden by specific metadata.
        Values of any existing default metadata are replaced by the new values.
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with metric
        $Metadata,
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger
    )
    begin
    {

    }
    Process
    {   
        foreach($key in $Metadata.Keys)
        {
            Write-Verbose "AiLogger: Setting default metadata $key = $($Metadata[$key])"
            if(-not $connection.TelemetryMetadata.ContainsKey($key))
            {
                Write-Verbose "AiLogger: Adding default metadata $key = $($Metadata[$key])"
            }
            else
            {
                Write-Verbose "AiLogger: Replacing default metadata $key = $($Metadata[$key])"
            }
            $connection.TelemetryMetadata[$key] = $Metadata[$key]
        }
    }
}
