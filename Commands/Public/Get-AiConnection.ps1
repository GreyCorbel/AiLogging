function Get-AiConnection {
    <#
    .SYNOPSIS
        Returns most recently created Application Insights connection
    #>
    [CmdletBinding()]
    param ()
    
    process {
        $script:LastCreatedAiLogger
    }
}
