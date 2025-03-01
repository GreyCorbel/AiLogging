Function Write-AiEvent
{
    <#
    .SYNOPSIS
        Traces event along with optional custom metadata and metrics.
        Usable when logging additional metrics associated with/related to the event that is not suitable to be logged standalone
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
            #Event to be traced
        $EventName,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Optional metrics to be sent with the event
        $Metrics=$null,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with the event
        $Metadata=$null,
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger
    )
    begin
    {
        EnsureInitialized -Connection $Connection
    }
    Process
    {
        $data = new-object Microsoft.ApplicationInsights.DataContracts.EventTelemetry($EventName)

        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        if($null -ne $Metrics) {
            foreach($key in $Metrics.Keys) {$data.Metrics[$Key] = $Metrics[$key]}
        }
        foreach($key in $Connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $Connection.telemetryMetadata[$key]}

        Write-Verbose "Writing event $EventName"
        $Connection.telemetryClient.TrackEvent($data)
    }
}
