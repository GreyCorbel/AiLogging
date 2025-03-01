Function New-AiMetric
{
    <#
    .SYNOPSIS
        Creates Dictionary<String,Double> suitable for adding custom metric values and then sending with Events or Exceptions as Metrics parameter
        Not suitable for sending standalone metrics - use Write-AiMetric instead
    #>
    Process
    {
        new-object 'System.Collections.Generic.Dictionary[String,Double]'
    }
}
