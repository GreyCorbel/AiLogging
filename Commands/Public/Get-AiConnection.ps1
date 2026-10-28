function Get-AiConnection {
    <#
    .SYNOPSIS
        Returns the most recently created telemetry connection.

    .DESCRIPTION
        Returns the last connection created by Connect-AiLogger from module scope.
        Use this when you want to inspect or reuse the active telemetry connection.

    .OUTPUTS
        AiLogging.Connection

    .EXAMPLE
        Get-AiConnection

        Returns the active telemetry connection for the current session.
    #>
    [CmdletBinding()]
    param ()
    
    process {
        $script:LastCreatedAiLogger
    }
}
