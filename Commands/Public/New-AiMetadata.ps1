Function New-AiMetadata
{
    <#
    .SYNOPSIS
        Creates Dictionary<String,String> suitable for adding custom metadata and then sending with Events, Traces, Metrics or Exceptions as Metadata parameter
    #>
    Process
    {
        new-object 'System.Collections.Generic.Dictionary[String,String]'
    }
}
