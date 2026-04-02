Function Write-AiTrace
{
    <#
    .SYNOPSIS
        Writes a trace message with optional severity and metadata.

    .DESCRIPTION
        Writes trace telemetry to Application Insights. Trace messages are useful for operational
        logging and diagnostics. The default severity is Information.

    .PARAMETER Message
        Trace message to record.

    .PARAMETER Severity
        Severity level to associate with the trace. Defaults to Information.

    .PARAMETER Metadata
        Optional metadata dictionary to include with the trace.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.
    
    .EXAMPLE
        Write-AiTrace 'Beginning processing'

        Writes an informational trace by using the active connection.

    .EXAMPLE
        $meta = New-AiMetadata | Add-AiMetadata -Name 'Context' -Value 'MyContext' -PassThrough
        Write-AiTrace -Message "Performed context-specific action" -Metadata $meta

        Writes a trace with custom metadata.

    .EXAMPLE
        Write-AiTrace -Message 'Validation failed' -Severity Warning -Connection $connection

        Writes a warning trace on a specific connection.
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

    }
    Process
    {   
        $data = new-object Microsoft.ApplicationInsights.DataContracts.TraceTelemetry($Message, $Severity)
        if($null -ne $Metadata) {
            foreach($key in $Metadata.Keys) {$data.Properties[$Key] = $Metadata[$key]}
        }
        foreach($key in $connection.telemetryMetadata.Keys) {$data.Properties[$Key] = $connection.telemetryMetadata[$key]}

        Write-Verbose "AiLogger: Writing trace $Severity`: $Message"
        $connection.TrackTrace($data)
    }
}
