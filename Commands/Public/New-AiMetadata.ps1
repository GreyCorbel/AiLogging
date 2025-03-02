Function New-AiMetadata
{
    <#
    .SYNOPSIS
        Creates new metadata collection to be used with Add-AiMetadata
    #>
    param 
    (
        [Parameter()]
        [string]
            #Name of the metric
        $Name,
        [Parameter()]
        [string]
            #Value of the metric
        $Value
    )

    Process
    {
        $metadata = new-object 'System.Collections.Generic.Dictionary[String,String]'
        if(-not [string]::IsNullOrEmpty($Name)) {$metadata[$Name] = $Value}
        return $metadata
    }
}
