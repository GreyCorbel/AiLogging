Function Write-AiMetric
{
    <#
    .SYNOPSIS
        Logs metric value without any aggregation along with optional custom metadata
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Values of metrics to be sent
        $Metrics,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with metric
        $Metadata=$null,
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger,
        [switch]
            #Passes matrics from input to the pipeline
        $PassThrough
    )
    begin
    {
        $doLog = EnsureInitialized -Connection $Connection
    }
    Process
    {   
        if(-not $doLog) {return}
    
        foreach($key in $metrics.Keys)
        {
            $data = new-object Microsoft.ApplicationInsights.DataContracts.MetricTelemetry($key, $Metrics[$key])
            $data.MetricNamespace = $Connection.MetricNamespace

            if($null -ne $Metadata) {
                foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
            }
            foreach($key in $Connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $Connection.telemetryMetadata[$key]}

            Write-Verbose "Writing metric $Key = $($metrics[$Key])"
            $Connection.TrackMetric($data)
        }
    }
}
