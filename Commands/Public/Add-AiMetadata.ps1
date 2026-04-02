function Add-AiMetadata {
    <#
    .SYNOPSIS
        Adds a metadata entry to a metadata dictionary.

    .DESCRIPTION
        Adds a named metadata value to a dictionary created by New-AiMetadata.
        If the metadata name already exists, the value is only replaced when -Force is used.
        Use -PassThrough to keep the dictionary on the pipeline for chaining.

    .PARAMETER Metadata
        Metadata dictionary created by New-AiMetadata.

    .PARAMETER Name
        Metadata key to add.

    .PARAMETER Value
        Metadata value to add.

    .PARAMETER Force
        Replaces an existing metadata value when the same key is already present.

    .PARAMETER PassThrough
        Returns the updated metadata dictionary so you can continue piping it.

    .EXAMPLE
        New-AiMetadata | Add-AiMetadata -Name 'TenantId' -Value 'contoso' -PassThrough

        Creates a metadata dictionary, adds a key, and emits the updated dictionary.

    .EXAMPLE
        $metadata | Add-AiMetadata -Name 'Environment' -Value 'Prod' -Force

        Replaces the value of an existing metadata key named Environment.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [System.Collections.Generic.Dictionary[String,String]]
            #Metadata object created by New-AiMetadata
        $Metadata,

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
            #allows rewrite of already present metadata
        $Force,
        [switch]
            #causes input object to be passed to output, enabling chaining
        $PassThrough
    )
    
    process {
        if(-not $metadata.TryAdd($Name, $Value) ) {
            if($Force) {
                $metadata[$Name] = $Value
            } else {
                Write-Warning "Metadata with name $Name already exists. Use -Force to overwrite"
            }
        }
        if($PassThrough) {
            $metadata
        }
    }
}
