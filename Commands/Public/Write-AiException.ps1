Function Write-AiException
{
    <#
    .SYNOPSIS
        Traces exception along with optional custom metadata and metrics
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
        EnsureInitialized -Connection $Connection
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
        $Connection.TrackException($data)
    }
}
