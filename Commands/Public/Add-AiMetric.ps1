function Add-AiMetric {
    <#
    .SYNOPSIS
        Adds a metric entry to a metrics dictionary.

    .DESCRIPTION
        Adds a named metric value to a dictionary created by New-AiMetric.
        If the metric name already exists, the value is only replaced when -Force is used.
        Use -PassThrough to keep the dictionary on the pipeline for chaining.

    .PARAMETER Metrics
        Metrics dictionary created by New-AiMetric.

    .PARAMETER Name
        Metric name to add.

    .PARAMETER Value
        Metric value to add.

    .PARAMETER Force
        Replaces an existing metric value when the same name is already present.

    .PARAMETER PassThrough
        Returns the updated metrics dictionary so you can continue piping it.

    .EXAMPLE
        New-AiMetric | Add-AiMetric -Name 'ProcessedItems' -Value 42 -PassThrough

        Creates a metrics dictionary, adds a metric, and emits the updated dictionary.

    .EXAMPLE
        $metrics | Add-AiMetric -Name 'DurationMs' -Value 1375 -Force

        Replaces the value of an existing metric named DurationMs.
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
