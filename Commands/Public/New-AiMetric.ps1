Function New-AiMetric
{
    <#
    .SYNOPSIS
        Creates new metrics collection to be used with Add-AiMetric
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
