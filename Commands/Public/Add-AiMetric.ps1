function Add-AiMetric {
    <#
    .SYNOPSIS
        Adds new metric to provided metrics collection
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Metrics collection created by New-AiMetric
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
        [switch]
            #allows rewrite of already present metrics
        $Force,
        [switch]
            #causes input object to be passed to output, enabling chaining
        $PassThrough
    )
    
    process {
        if(-not $Metrics.TryAdd($Name, $Value)) {
            if($Force) {
                $Metrics[$Name] = $Value
            } else {
                Write-Warning "Metric with name $Name already exists. Use -Force to overwrite"
            }
        }
        if($PassThrough) {
            $Metrics
        }
    }
}
