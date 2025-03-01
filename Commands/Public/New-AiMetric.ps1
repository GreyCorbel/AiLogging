Function New-AiMetric
{
    <#
    .SYNOPSIS
        Creates new metrics collection to be used with Add-AiMetric
    #>
    Process
    {
        new-object 'System.Collections.Generic.Dictionary[String,Double]'
    }
}
