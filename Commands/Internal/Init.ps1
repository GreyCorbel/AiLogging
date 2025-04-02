function Init
{
    Add-Type -AssemblyName Microsoft.ApplicationInsights

    $typeData = Get-Content -Path $PSScriptRoot\Helpers\CloudRoleNameTelemetryInitializer.cs -Raw
    Add-Type -TypeDefinition $typeData -ReferencedAssemblies Microsoft.ApplicationInsights
}