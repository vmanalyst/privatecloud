# Health checks (morning checks)

```powershell
Connect-VIServer vcenter.company.local -Credential (Get-Credential)
```

All read-only. **No output = nothing wrong** for most of these.
For vSAN health see 05-vsan.md; for NSX see 06-nsx.md.

## vCenter alarms that are firing now

```powershell
$root = Get-View (Get-View ServiceInstance).Content.RootFolder
$root.TriggeredAlarmState | ForEach-Object {
    [pscustomobject]@{
        Object = (Get-View $_.Entity -Property Name).Name
        Alarm  = (Get-View $_.Alarm).Info.Name
        Status = $_.OverallStatus          # red / yellow
        Since  = $_.Time
    }
} | Sort-Object Status, Since | Format-Table -AutoSize
```

## Hosts

```powershell
# hosts not connected, or in maintenance mode
Get-VMHost | Where-Object ConnectionState -ne 'Connected' | Select-Object Name, ConnectionState, PowerState

# SSH left running
Get-VMHost | Where-Object ConnectionState -eq 'Connected' | Get-VMHostService |
    Where-Object { $_.Key -eq 'TSM-SSH' -and $_.Running } | Select-Object VMHost

# builds that don't match the rest of the cluster
Get-VMHost | Group-Object { $_.Parent.Name } | ForEach-Object {
    $_.Group | Group-Object Build | Select-Object @{N='Cluster';E={$_.Group[0].Parent}}, Name, Count
}
```

## Clusters: HA and DRS

```powershell
Get-Cluster | Select-Object Name, HAEnabled, HAAdmissionControlEnabled,
    DrsEnabled, DrsAutomationLevel, VsanEnabled
```

HA off, or DRS not `FullyAutomated`, means maintenance mode won't move VMs off for you.

## Datastores

```powershell
# under 20% free
Get-Datastore | Where-Object { $_.FreeSpaceGB / $_.CapacityGB -lt 0.2 } |
    Select-Object Name, @{N='FreeGB';E={[math]::Round($_.FreeSpaceGB)}},
        @{N='Free%';E={[math]::Round($_.FreeSpaceGB / $_.CapacityGB * 100)}}

# dead storage paths
Get-VMHost | Where-Object ConnectionState -eq 'Connected' |
    Get-ScsiLun -LunType disk -ErrorAction SilentlyContinue | Get-ScsiLunPath |
    Where-Object State -eq 'Dead' |
    Select-Object @{N='Host';E={$_.ScsiLun.VMHost.Name}}, @{N='LUN';E={$_.ScsiLun.CanonicalName}}, Name
```

## VMs

```powershell
# snapshots older than 3 days
Get-VM | Get-Snapshot | Where-Object Created -lt (Get-Date).AddDays(-3) |
    Select-Object VM, Name, Created, @{N='SizeGB';E={[math]::Round($_.SizeGB, 1)}}

# VMware Tools not OK on powered-on VMs
Get-VM | Where-Object PowerState -eq 'PoweredOn' |
    Select-Object Name, @{N='Tools';E={$_.ExtensionData.Guest.ToolsVersionStatus2}},
        @{N='Running';E={$_.ExtensionData.Guest.ToolsRunningStatus}} |
    Where-Object { $_.Tools -ne 'guestToolsCurrent' -or $_.Running -ne 'guestToolsRunning' }

# CD-ROM / ISO still connected (blocks vMotion and maintenance mode)
Get-VM | Get-CDDrive | Where-Object { $_.ConnectionState.Connected -or $_.IsoPath } |
    Select-Object Parent, IsoPath

# disks needing consolidation (left over after backups)
Get-VM | Where-Object { $_.ExtensionData.Runtime.ConsolidationNeeded } | Select-Object Name

# powered-off VMs (candidates for clean-up)
Get-VM | Where-Object PowerState -eq 'PoweredOff' |
    Select-Object Name, @{N='Folder';E={$_.Folder.Name}}

# VMs on a local datastore (no HA or vMotion for them)
Get-VM | Where-Object { ($_ | Get-Datastore).ExtensionData.Summary.MultipleHostAccess -contains $false } |
    Select-Object Name, @{N='Datastore';E={($_ | Get-Datastore).Name -join ', '}}
```

## Put it all in one email or file

See 09-reports.md and weekly-report.ps1: the same checks, run together, saved as one HTML report.
