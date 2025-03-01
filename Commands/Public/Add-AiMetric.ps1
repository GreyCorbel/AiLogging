function Add-AiMetric {
    <#
    .SYNOPSIS
        Registers additional metadata to be sent with all telemetry produced after registered - until removed by call of Remove-AiMetadata or Reset-AiMetadata
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Metadata object created by New-AiMetric
        $Metrics,

        [Parameter(Mandatory)]
        [string]
            #Name of metadata to be registered. Will become custom dimension of telemetry data
            #Allows for easy searching/filtering in ApplicationInsights logs
        $Name,

        [Parameter(Mandatory)]
        [string]
            #Value of metadata
        $Value,
        [switch]$PassThrough
    )
    
    process {
        $Metrics.Add($Name, $Value) | Out-Null
        if($PassThrough) {
            $Metrics
        }
    }
}
