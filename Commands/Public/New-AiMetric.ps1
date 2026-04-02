Function New-AiMetric
{
    <#
    .SYNOPSIS
        Creates a metrics dictionary.

    .DESCRIPTION
        Creates a System.Collections.Generic.Dictionary[String,Double] for metric values.
        You can optionally seed it with an initial metric and then add more entries with Add-AiMetric.

    .PARAMETER Name
        Optional initial metric name.

    .PARAMETER Value
        Optional initial metric value.

    .OUTPUTS
        System.Collections.Generic.Dictionary[String,Double]

    .EXAMPLE
        New-AiMetric

        Creates an empty metrics dictionary.

    .EXAMPLE
        New-AiMetric -Name 'ProcessedItems' -Value 42

        Creates a metrics dictionary with a single initial metric.
    #>
    param 
    (
        [Parameter()]
        [string]
            #Name of the metric
        $Name,
        [Parameter()]
        [double]
            #Value of the metric
        $Value
    )
    Process
    {
        $metric = new-object 'System.Collections.Generic.Dictionary[String,Double]'
        if(-not [string]::IsNullOrEmpty($Name)) {$metric[$Name] = $Value}
        return $metric
    }
}
