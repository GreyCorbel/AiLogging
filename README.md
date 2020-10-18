# AiLogging poweshell module

This module helps creators of powershell scripts, including Azure automation modules to easily send events to AppInsights, so the module logs its activity a standard way, expected by operational and support teams. No longer text file logs with application specific format!

# Examples
How to easily use it from inside PowerShell automation runbook to log beginning and end of processing and result of call to external service.
Dependency iswritten to AppInsight instance, showing called component in application map along with information about how long the call took and if it was successful.
```ps
#when executed in automation account, discovers auutomation job it runs within
Function Get-Self
{
    if($null -ne $PSPrivateMetadata.JobId.Guid)
    {
        $Error.Clear()
        $accounts = @(Get-AzAutomationAccount -ErrorAction SilentlyContinue)
        if($Error.Count -eq 0)
        {
            foreach($acct in $accounts)
            {
                $job = Get-AzAutomationJob -ResourceGroupName $acct.ResourceGroupName -AutomationAccountName $acct.AutomationAccountName -Id $PSPrivateMetadata.JobId.Guid -ErrorAction SilentlyContinue
                if (!([string]::IsNullOrEmpty($job))) { Break; }
            }
            $job
        }
        else
        {
            Write-Warning "You must call Login-AzAccount for automatic recognition of automation account we're running in"
            $Error.Clear()
        }
    }
}


$aiKey = (Get-AutomationVariable -Name 'AI-InstrumentationKey')
$self = Get-Self
if($null -ne $self)
{
    Import-Module AiLogging -ArgumentList $aiKey,$self.AutomationAccountName, $self.RunbookName, $env:COMPUTERNAME
}

Write-AiTrace -Message 'Beginning processing'

#do some processing
$Start=Get-Date
$result = Call-ExternalService -Host $someHttpServer
Write-AiDependency -Target $someHttpServer -TypeName Http -Name 'CallExternalService' -Start $start -Duration ((Get-Date)-$start) -Success $result.IsSuccess

Write-AiTrace -Message 'Finishing processing'

```