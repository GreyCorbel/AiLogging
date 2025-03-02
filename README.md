# AiLogging PowerShell module

This module helps creators of powershell scripts, including Azure automation modules to easily send events to AppInsights, so the module logs its activity a standard way, expected by operational and support teams. No longer text file logs with application specific format!

# Examples
How to easily use it from inside PowerShell automation runbook to log beginning and end of processing and result of call to external service.
Dependency is written to AppInsight instance, showing called component in application map along with information about how long the call took and if it was successful.

```powershell
$ConnectionString = (Get-AutomationVariable -Name 'ApplicationInsightsConnectionString')
Connect-AiLogger `
    -ConnectionString $ConnectionString `
    -Application 'myAutomationAccount' `
    -Module 'MyRunbook' `

Write-AiTrace -Message 'Beginning processing'

#do some processing
$Start=Get-Date

$result = Call-ExternalService -Host $someHttpServer
Write-AiDependency -Target $someHttpServer -TypeName WebServer -Name 'CallExternalService' -Start $start -Success $result.IsSuccess
if($result.IsSuccess)
{
    New-AiMetric `
    | Add-AiMetric -Name ExternalRecordsReturned -Value $result.value.Count `
    | Write-AiMetric

}
Write-AiTrace -Message 'Finishing processing'

```