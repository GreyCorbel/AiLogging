Function Write-AiTrace
{
    <#
    .SYNOPSIS
        Writes trace message with severity and optional custom metadata.
        Default severity level is Verbose
    
    .EXAMPLE
        Write-AiTrace 'Beginning processing'

    .EXAMPLE
        $meta = New-AiMetadata
        $meta['Context']='MyContext'
        Write-AiTrace -Message "Performed context-specific action" -AdditionalMetadata $meta
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
            #Message to be traced
        $Message,
        [Parameter()]
        [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]
            #Severity of message sent
        $Severity='Information',
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,String]]
            #Optional metadata to be sent with trace
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
        $data = new-object Microsoft.ApplicationInsights.DataContracts.TraceTelemetry($Message, $Severity)
        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        foreach($key in $connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $connection.telemetryMetadata[$key]}

        $connection.TrackTrace($data)
    }
}
