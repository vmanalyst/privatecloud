<#
  vSphere weekly report - READ-ONLY. Changes nothing.
  Usage:  pwsh -File .\weekly-report.ps1
          (another vCenter: add -VCenter <name>)
  Login:  uses C:\Scripts\vcenter-cred.xml if it exists, otherwise asks for the password.
          Create that file once (as the user that will run the script):
            Get-Credential -UserName svc-automation@vsphere.local -Message "vCenter" |
                Export-Clixml C:\Scripts\vcenter-cred.xml
#>
param(
    [string] $VCenter   = "vcenter.lab.internal",
    [string] $User      = "svc-automation@vsphere.local",
    [string] $CredFile  = "C:\Scripts\vcenter-cred.xml",
    [string] $OutFolder = "C:\Reports",
    [int]    $SnapshotDays = 3,
    [int]    $DatastoreFreePct = 20
)

# ---- connect ---------------------------------------------------------------
if (Test-Path $CredFile) { $cred = Import-Clixml $CredFile } else { $cred = Get-Credential -UserName $User -Message "Password for $User on $VCenter" }
Connect-VIServer $VCenter -Credential $cred -ErrorAction Stop | Out-Null
New-Item -ItemType Directory $OutFolder -Force | Out-Null

$hosts     = Get-VMHost
$connected = $hosts | Where-Object ConnectionState -eq 'Connected'
$vms       = Get-VM

# ---- checks (each one is a small table) ------------------------------------
$sections = [ordered]@{}

$sections['Hosts not connected'] = $hosts | Where-Object ConnectionState -ne 'Connected' |
    Select-Object Name, ConnectionState, PowerState

$root = Get-View (Get-View ServiceInstance).Content.RootFolder
$sections['vCenter alarms firing'] = $root.TriggeredAlarmState | ForEach-Object {
    [pscustomobject]@{
        Object = (Get-View $_.Entity -Property Name).Name
        Alarm  = (Get-View $_.Alarm).Info.Name
        Status = $_.OverallStatus
        Since  = $_.Time
    }
}

$sections['Host versions'] = $hosts | Select-Object Name, @{N='Cluster';E={$_.Parent}}, Version, Build |
    Sort-Object Cluster, Name

$sections['SSH running'] = $connected | Get-VMHostService |
    Where-Object { $_.Key -eq 'TSM-SSH' -and $_.Running } | Select-Object VMHost

$sections["Datastores under $DatastoreFreePct% free"] = Get-Datastore |
    Where-Object { $_.CapacityGB -gt 0 -and ($_.FreeSpaceGB / $_.CapacityGB * 100) -lt $DatastoreFreePct } |
    Select-Object Name, @{N='CapacityGB';E={[math]::Round($_.CapacityGB)}},
        @{N='FreeGB';E={[math]::Round($_.FreeSpaceGB)}},
        @{N='Free%';E={[math]::Round($_.FreeSpaceGB / $_.CapacityGB * 100)}}

$sections['Dead storage paths'] = $connected |
    Get-ScsiLun -LunType disk -ErrorAction SilentlyContinue | Get-ScsiLunPath -ErrorAction SilentlyContinue |
    Where-Object State -eq 'Dead' |
    Select-Object @{N='Host';E={$_.ScsiLun.VMHost.Name}}, @{N='LUN';E={$_.ScsiLun.CanonicalName}}, Name

$sections["Snapshots older than $SnapshotDays days"] = $vms | Get-Snapshot |
    Where-Object Created -lt (Get-Date).AddDays(-$SnapshotDays) |
    Select-Object VM, Name, Created, @{N='SizeGB';E={[math]::Round($_.SizeGB, 1)}}

$sections['VMware Tools not OK'] = $vms | Where-Object PowerState -eq 'PoweredOn' |
    Select-Object Name, @{N='Tools';E={$_.ExtensionData.Guest.ToolsVersionStatus2}},
        @{N='Running';E={$_.ExtensionData.Guest.ToolsRunningStatus}} |
    Where-Object { $_.Tools -ne 'guestToolsCurrent' -or $_.Running -ne 'guestToolsRunning' }

$sections['CD-ROM connected'] = $vms | Get-CDDrive |
    Where-Object { $_.ConnectionState.Connected -or $_.IsoPath } | Select-Object Parent, IsoPath

$sections['Disks needing consolidation'] = $vms |
    Where-Object { $_.ExtensionData.Runtime.ConsolidationNeeded } | Select-Object Name

$sections['Clusters: HA / DRS'] = Get-Cluster |
    Select-Object Name, HAEnabled, DrsEnabled, DrsAutomationLevel, VsanEnabled

# ---- build the HTML page ---------------------------------------------------
$style = @"
<style>
 body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#13212E}
 h1{font-size:22px} h2{font-size:16px;margin-top:28px}
 table{border-collapse:collapse;font-size:13px} th,td{border:1px solid #ccc;padding:4px 8px}
 th{background:#ECE9E1} .ok{color:#2E7D32} .bad{color:#B3261E}
</style>
"@
$body = "<h1>vSphere weekly report: $VCenter</h1><p>$(Get-Date -Format 'dddd dd MMM yyyy HH:mm')</p>"
$body += "<p>$($hosts.Count) hosts ($($connected.Count) connected), $($vms.Count) VMs</p>"

foreach ($name in $sections.Keys) {
    $rows = @($sections[$name])
    if ($rows.Count -eq 0) {
        $body += "<h2 class='ok'>&#10003; ${name}: none</h2>"
    } else {
        $body += "<h2 class='bad'>$name ($($rows.Count))</h2>"
        $body += ($rows | ConvertTo-Html -Fragment) -join ''
    }
}

$file = Join-Path $OutFolder ("vsphere-weekly-{0}.html" -f (Get-Date -Format 'yyyy-MM-dd'))
ConvertTo-Html -Head $style -Body $body -Title "vSphere weekly report" | Out-File $file -Encoding utf8
Disconnect-VIServer -Confirm:$false
Write-Host "Report saved: $file"