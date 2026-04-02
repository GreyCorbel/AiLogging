Function New-AiMetadata
{
    <#
    .SYNOPSIS
        Creates a metadata dictionary.

    .DESCRIPTION
        Creates a System.Collections.Generic.Dictionary[String,String] for telemetry metadata.
        You can optionally seed it with an initial key-value pair and then add more entries with Add-AiMetadata.

    .PARAMETER Name
        Optional initial metadata key.

    .PARAMETER Value
        Optional initial metadata value.

    .OUTPUTS
        System.Collections.Generic.Dictionary[String,String]

    .EXAMPLE
        New-AiMetadata

        Creates an empty metadata dictionary.

    .EXAMPLE
        New-AiMetadata -Name 'TenantId' -Value 'contoso'

        Creates a metadata dictionary with a single initial entry.
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
