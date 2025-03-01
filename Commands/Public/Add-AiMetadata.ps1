function Add-AiMetadata {
    <#
    .SYNOPSIS
        Adds new metadata to provided metadata collection
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
