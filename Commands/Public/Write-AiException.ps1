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
        $exceptions = New-Object System.Collections.Generic.List[object]
        $current = $Exception
        $outerId = 0
        while($null -ne $current)
        {
            $id = $current.GetHashCode()
            $stack = "$($current.StackTrace)"
            $exceptions.Add([ordered]@{
                id = $id
                outerId = $outerId
                typeName = $current.GetType().FullName
                message = "$($current.Message)"
                hasFullStack = $true
                stack = $stack.Substring(0, [Math]::Min($stack.Length, 32768))
            })
            $outerId = $id
            $current = $current.InnerException
        }
        $baseData = [ordered]@{
            exceptions = $exceptions.ToArray()
            severityLevel = 'Error'
        }
        if($null -ne $Metrics) { $baseData['measurements'] = $Metrics }
        $envelope = New-AiEnvelope -Connection $Connection -TelemetryType Exception -BaseData $baseData -Metadata $Metadata

        Write-Verbose "AiLogger: Writing exception $($Exception.Message)"
        Add-AiTelemetry -Connection $Connection -Envelope $envelope
    }
}
