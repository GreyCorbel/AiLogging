Function Write-AiMetric
{
    <#
    .SYNOPSIS
        Logs metric values with optional metadata.

    .DESCRIPTION
        Writes each metric in a metrics dictionary to Application Insights without local aggregation.
        The metric namespace is taken from the connection created by Connect-AiLogger.

    .PARAMETER Metrics
        Metrics dictionary to write.

    .PARAMETER Metadata
        Optional metadata dictionary to include with every metric written by this call.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.

    .EXAMPLE
        New-AiMetric -Name 'ProcessedItems' -Value 42 | Write-AiMetric

        Writes a single metric by using the active connection.

    .EXAMPLE
        $metrics | Write-AiMetric -Metadata $metadata -Connection $connection

        Writes multiple metrics together with shared metadata.
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
        $Connection = $script:LastCreatedAiLogger
    )
    begin
    {

    }
    Process
    {   
        foreach($metricKey in $metrics.Keys)
        {
            $baseData = [ordered]@{
                metrics = @(
                    [ordered]@{
                        ns = $Connection.MetricNamespace
                        name = $metricKey
                        kind = 0
                        value = $Metrics[$metricKey]
                        count = 1
                    }
                )
            }
            $envelope = New-AiEnvelope -Connection $Connection -TelemetryType Metric -BaseData $baseData -Metadata $Metadata

            Write-Verbose "AiLogger: Writing metric $metricKey = $($metrics[$metricKey])"
            Add-AiTelemetry -Connection $Connection -Envelope $envelope
        }
    }
}
