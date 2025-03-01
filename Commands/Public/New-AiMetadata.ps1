Function New-AiMetadata
{
    <#
    .SYNOPSIS
        Creates new metadata collection to be used with Add-AiMetadata
    #>
    Process
    {
        new-object 'System.Collections.Generic.Dictionary[String,String]'
    }
}
