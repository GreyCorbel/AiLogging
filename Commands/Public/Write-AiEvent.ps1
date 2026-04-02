Function Write-AiEvent
{
    <#
    .SYNOPSIS
        Logs an event with optional metadata and metrics.

    .DESCRIPTION
        Writes event telemetry to Application Insights. Use events for important business or workflow
        milestones that may also carry related metadata and numeric measurements.

    .PARAMETER EventName
        Name of the event to record.

    .PARAMETER Metrics
        Optional metrics dictionary to include with the event.

    .PARAMETER Metadata
        Optional metadata dictionary to include with the event.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.

    .EXAMPLE
        Write-AiEvent -EventName 'IngestionStarted'

        Writes a simple event using the active connection.

    .EXAMPLE
        Write-AiEvent -EventName 'IngestionCompleted' -Metadata $metadata -Metrics $metrics -Connection $connection

        Writes an event with additional metadata and metrics.
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

        Write-Verbose "AiLogger: Writing event $EventName"
        $Connection.TrackEvent($data)
    }
}
