# AiLogging PowerShell Module

AiLogging is a PowerShell module for sending telemetry from scripts and automation runbooks to Azure Application Insights.

It helps you replace ad-hoc text logs with structured telemetry that is easy to search, alert on, and visualize in Application Insights.

## Why Use AiLogging

- Unified logging style across scripts and runbooks.
- Native telemetry types: traces, events, metrics, dependencies, and exceptions.
- Shared default metadata attached to every telemetry item.
- Dependency telemetry contributes to Application Insights Application Map.
- Pipeline-friendly helpers for building metadata and metric dictionaries.

## Requirements

- PowerShell 5.1+
- PowerShell Core compatible (`CompatiblePSEditions = Core` in module manifest)
- Azure Application Insights connection string

Set the connection string in environment variable `APPLICATIONINSIGHTS_CONNECTION_STRING`, or pass it directly to `Connect-AiLogger`.

## Install / Import

If you are using this repository directly, import the module manifest:

```powershell
Import-Module .\Module\AiLogging\AiLogging.psd1 -Force
```

## Quick Start

```powershell
# Optional: set this once per session if not already configured by your host
$env:APPLICATIONINSIGHTS_CONNECTION_STRING = 'InstrumentationKey=...;IngestionEndpoint=https://...'

# Create a telemetry connection and default dimensions
$connection = Connect-AiLogger `
    -Application 'myAutomationAccount' `
    -Component 'MyRunbook' `
    -Role 'HybridWorker' `
    -Instance $env:COMPUTERNAME

Write-AiTrace -Message 'Beginning processing' -Connection $connection

$start = Get-Date
$result = Call-ExternalService -Host $someHttpServer

Write-AiDependency `
    -Target $someHttpServer `
    -DependencyType 'WebServer' `
    -Name 'CallExternalService' `
    -Start $start `
    -Success $result.IsSuccess `
    -Connection $connection

if ($result.IsSuccess) {
    New-AiMetric `
    | Add-AiMetric -Name 'ExternalRecordsReturned' -Value $result.Value.Count -PassThrough `
    | Write-AiMetric -Connection $connection
}

Write-AiTrace -Message 'Finishing processing' -Connection $connection

# Flush buffered telemetry before script exits
Submit-AiData -Connection $connection
```

## Metadata and Metrics Helpers

Build dictionaries with `New-*` + `Add-*`, then pass to telemetry commands:

```powershell
$metadata = New-AiMetadata `
| Add-AiMetadata -Name 'TenantId' -Value 'contoso' -PassThrough `
| Add-AiMetadata -Name 'RunId' -Value $PSPrivateMetadata.JobId -PassThrough

$metrics = New-AiMetric `
| Add-AiMetric -Name 'ProcessedItems' -Value 42 -PassThrough `
| Add-AiMetric -Name 'DurationMs' -Value 1375 -PassThrough

Write-AiEvent -EventName 'IngestionCompleted' -Metadata $metadata -Metrics $metrics
```

To update default metadata for all future telemetry on a connection:

```powershell
New-AiMetadata -Name 'Environment' -Value 'Prod' | Set-AiDefaultMetadata
```

## Exception Logging Example

```powershell
try {
    Invoke-RiskyOperation
}
catch {
    $exceptionMetadata = New-AiMetadata -Name 'Operation' -Value 'RiskyOperation'
    $_.Exception | Write-AiException -Metadata $exceptionMetadata
    throw
}
```

## Exported Commands

### Connection and Context

- `Connect-AiLogger`
- `Get-AiConnection`
- `Set-AiDefaultMetadata`

### Builders

- `New-AiMetadata`
- `Add-AiMetadata`
- `New-AiMetric`
- `Add-AiMetric`

### Telemetry Writers

- `Write-AiTrace`
- `Write-AiEvent`
- `Write-AiMetric`
- `Write-AiDependency`
- `Write-AiException`

### Delivery

- `Submit-AiData`

## Notes

- Most commands default to the most recently created connection if `-Connection` is not provided.
- Connection string is optional for `Connect-AiLogger`, but telemetry cannot be sent without it.
- `Submit-AiData` should be called before process exit in short-lived scripts/runbooks to reduce telemetry loss.