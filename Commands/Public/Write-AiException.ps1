Function Write-AiException
{
    <#
    .SYNOPSIS
        Logs an exception with optional metadata and metrics.

    .DESCRIPTION
        Writes exception telemetry to Application Insights. Use this command inside catch blocks
        to record exceptions together with relevant metadata and measurements.

    .PARAMETER Exception
        Exception instance to record.

    .PARAMETER Metrics
        Optional metrics dictionary to include with the exception telemetry.

    .PARAMETER Metadata
        Optional metadata dictionary to include with the exception telemetry.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.

    .EXAMPLE
        try {
            Invoke-RiskyOperation
        }
        catch {
            $_.Exception | Write-AiException
        }

        Writes the caught exception by using the pipeline.

    .EXAMPLE
        $_.Exception | Write-AiException -Metadata $metadata -Metrics $metrics -Connection $connection

        Writes the exception together with additional context.
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Exception]
            #Exception to be traced
        $Exception,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Optional metrics to be sent with exception
        $Metrics=$null,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with exception
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
        $data = new-object Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry($Exception)
        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        if($null -ne $Metrics) {
            foreach($key in $Metrics.Keys) {$data.Metrics[$Key] = $Metrics[$key]}
        }
        foreach($key in $Connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $Connection.telemetryMetadata[$key]}

        Write-Verbose "AiLogger: Writing exception $($Exception.Message)"
        $Connection.TrackException($data)
    }
}
