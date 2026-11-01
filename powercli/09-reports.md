# Reports and scheduling

## Export any report to CSV

Add to the end of any `Select-Object` line:

```powershell
| Export-Csv -Path C:\Reports\vm-report.csv -NoTypeInformation
```

Excel opens the CSV directly. Make the folder once: `New-Item -ItemType Directory C:\Reports -Force`

## Save the login once (no password in the script)

```powershell
# run once, AS THE ACCOUNT THAT WILL RUN THE SCHEDULED TASK, on the same PC
Get-Credential | Export-Clixml -Path C:\Scripts\vcenter-cred.xml
```

The file is encrypted by Windows and only works for that user on that PC. Never put it in Git
(add `*.xml` creds to `.gitignore`).

## The weekly report

`weekly-report.ps1` runs the main checks from 07-health.md and saves one HTML page you can open
in a browser or attach to an email. It only reads; it changes nothing.

Run it by hand first:

```powershell
cd C:\privatecloud\powercli
pwsh -File .\weekly-report.ps1 -VCenter vcenter.company.local
```

It writes `C:\Reports\vsphere-weekly-YYYY-MM-DD.html`.

## Run it every Monday (Windows Task Scheduler)

Task Scheduler → Create Task:

| Setting | Value |
| --- | --- |
| Run as | a service account (the one you saved the login with) |
| Trigger | Weekly, Monday 07:00 |
| Program | `pwsh.exe` |
| Arguments | `-NoProfile -ExecutionPolicy Bypass -File C:\privatecloud\powercli\weekly-report.ps1 -VCenter vcenter.company.local` |

Same with one command (preview by reading it, then run):

```powershell
$action  = New-ScheduledTaskAction -Execute "pwsh.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\privatecloud\powercli\weekly-report.ps1 -VCenter vcenter.company.local"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 7am
Register-ScheduledTask -TaskName "vSphere weekly report" -Action $action -Trigger $trigger `
  -User "CORP\svc-reports" -Password (Read-Host "svc-reports password")
```
