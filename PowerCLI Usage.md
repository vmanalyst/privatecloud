# PowerCLI quick guide

Everyday vSphere tasks from the command line. Written for a typical customer
site (Windows jump server or admin workstation). The same commands work on
Linux; see the end of this guide.

## 1. Install (Windows)

Open **PowerShell** (Windows PowerShell 5.1 or PowerShell 7 both work).

```powershell
# allow locally created scripts to run (once, for your user)
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# install PowerCLI from the PowerShell Gallery
Install-Module -Name VCF.PowerCLI -Scope CurrentUser

# lab/self-signed certificates and no telemetry prompt
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCEIP $false -Scope User -Confirm:$false
```

### No internet on the jump server? 

On a machine **with** internet:

```powershell
Save-Module -Name VCF.PowerCLI -Path C:\Temp\PowerCLI
```

Copy the contents of `C:\Temp\PowerCLI` to the jump server, into:

- Windows PowerShell 5.1: `C:\Program Files\WindowsPowerShell\Modules`
- PowerShell 7: `C:\Program Files\PowerShell\Modules`

Then on the jump server:

```powershell
Get-ChildItem "C:\Program Files\WindowsPowerShell\Modules" -Recurse | Unblock-File
Get-Module -Name VCF.PowerCLI -ListAvailable
```

Many sites install it for you. If `Get-Module -ListAvailable` already shows it, skip all of this.

## 2. Connect / disconnect

```powershell
# with your AD account (prompts for user and password)
Connect-VIServer vcenter.company.local -Credential (Get-Credential)

# or with a named account
Connect-VIServer vcenter.company.local -User svc-automation@vsphere.local

Disconnect-VIServer -Confirm:$false
```

## 3. Common Usage

```powershell
# VMs: name, power, CPU, RAM, IP, folder
Get-VM | Select-Object Name, PowerState, NumCpu, MemoryGB,
    @{N='IP';E={$_.Guest.IPAddress -join ','}},
    @{N='Folder';E={$_.Folder.Name}} | Sort-Object Name

# Hosts: state, version, CPU and memory use
Get-VMHost | Select-Object Name, ConnectionState, Version,
    @{N='CPU%';E={[math]::Round($_.CpuUsageMhz / $_.CpuTotalMhz * 100)}},
    @{N='Mem%';E={[math]::Round($_.MemoryUsageGB / $_.MemoryTotalGB * 100)}}

# Datastores: size, free space, % free
Get-Datastore | Select-Object Name,
    @{N='CapacityGB';E={[math]::Round($_.CapacityGB)}},
    @{N='FreeGB';E={[math]::Round($_.FreeSpaceGB)}},
    @{N='Free%';E={[math]::Round($_.FreeSpaceGB / $_.CapacityGB * 100)}}

# VM folders as full paths
Get-Folder -Type VM | Where-Object Name -ne 'vm' | ForEach-Object {
    $path = $_.Name; $p = $_.Parent
    while ($p -and $p.Name -ne 'vm') { $path = "$($p.Name)/$path"; $p = $p.Parent }
    $path
} | Sort-Object
```

## 4. Power

```powershell
Start-VM         -VM web01 -Confirm:$false     # power on
Shutdown-VMGuest -VM web01 -Confirm:$false     # clean OS shutdown (needs VMware Tools)
Restart-VMGuest  -VM web01 -Confirm:$false     # clean OS restart
Stop-VM          -VM web01 -Confirm:$false     # hard power off - last resort
```

## 5. Snapshots

```powershell
New-Snapshot -VM web01 -Name "pre-patch" -Description "before monthly patches"

# all snapshots, with age and size
Get-VM | Get-Snapshot | Select-Object VM, Name, Created,
    @{N='SizeGB';E={[math]::Round($_.SizeGB, 1)}} | Sort-Object Created

# snapshots older than 7 days
Get-VM | Get-Snapshot | Where-Object Created -lt (Get-Date).AddDays(-7)

# remove one snapshot (check the name first!)
Get-Snapshot -VM web01 -Name "pre-patch" | Remove-Snapshot -Confirm:$false
```

## 6. Move a VM to another folder

```powershell
$folder = Get-Folder -Name "Apps" -Location (Get-Folder -Name "Banking")
Move-VM -VM web01 -InventoryLocation $folder
```

## 7. Tags

```powershell
Get-TagAssignment -Entity (Get-VM web01)                              # show tags
New-TagAssignment -Tag (Get-Tag -Name "Prod") -Entity (Get-VM web01)  # add a tag
Get-VM -Tag "Prod"                                                    # all VMs with a tag
```

## 8. Health checks

```powershell
# VMware Tools status
Get-VM | Select-Object Name, @{N='Tools';E={$_.ExtensionData.Guest.ToolsVersionStatus2}}

# datastores under 20% free
Get-Datastore | Where-Object { $_.FreeSpaceGB / $_.CapacityGB -lt 0.2 } |
    Select-Object Name, @{N='FreeGB';E={[math]::Round($_.FreeSpaceGB)}}

# powered-off VMs
Get-VM | Where-Object PowerState -eq 'PoweredOff' |
    Select-Object Name, @{N='Folder';E={$_.Folder.Name}}
```

## 9. Export any report to CSV

Add to the end of any `Select-Object` line:

```powershell
| Export-Csv -Path C:\Reports\vm-report.csv -NoTypeInformation
```

## 10. Run a report every morning (Windows Task Scheduler)

Save your commands as `C:\Scripts\daily-report.ps1`, then create a scheduled task:

```text
Program:   powershell.exe
Arguments: -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\daily-report.ps1
```

Use a service account for the task, never your own login.

## 11. Permissions and roles (audit exports)

```powershell
# ALL permissions in vCenter: who, which role, on what, does it propagate
Get-VIPermission | Select-Object @{N='Object';E={$_.Entity.Name}},
    @{N='ObjectType';E={$_.EntityId.Split('-')[0]}},
    Principal, Role, Propagate, IsGroup |
    Export-Csv -Path C:\Reports\vcenter-permissions.csv -NoTypeInformation

# permissions on one folder
Get-VIPermission -Entity (Get-Folder -Name "Banking") |
    Select-Object Principal, Role, Propagate, IsGroup

# who has access to one VM
Get-VIPermission -Entity (Get-VM web01) | Select-Object Principal, Role, Propagate

# every folder with its permissions, in one CSV
Get-Folder -Type VM | Where-Object Name -ne 'vm' | ForEach-Object {
    $folder = $_
    Get-VIPermission -Entity $folder | Select-Object @{N='Folder';E={$folder.Name}},
        Principal, Role, Propagate, IsGroup
} | Export-Csv -Path C:\Reports\folder-permissions.csv -NoTypeInformation

# all roles and the privileges inside each one
Get-VIRole | Select-Object Name, IsSystem,
    @{N='Privileges';E={$_.PrivilegeList -join '; '}} |
    Export-Csv -Path C:\Reports\vcenter-roles.csv -NoTypeInformation

# only custom roles (the ones your team created)
Get-VIRole | Where-Object IsSystem -eq $false | Select-Object Name
```

### Grant access to a folder

```powershell
New-VIPermission -Entity (Get-Folder -Name "Banking") `
    -Principal "CORP\Banking-VM-Admins" `
    -Role "Virtual machine user" `
    -Propagate:$true
```

`-Propagate:$true` means the permission also applies to every subfolder and VM inside.
Prefer AD **groups** over individual users, so access changes happen in AD, not vCenter.

### Copy a role (e.g. as a backup before editing it)

```powershell
New-VIRole -Name "Automation-Backup" -Privilege (Get-VIPrivilege -Role "Automation-Packer-Terraform")
```

## 12. Storage and multipathing

```powershell
# every VM disk: size, thin/thick, and its datastore path
Get-VM | Get-HardDisk | Select-Object @{N='VM';E={$_.Parent.Name}},
    Name, CapacityGB, StorageFormat, Filename |
    Export-Csv -Path C:\Reports\vm-disks.csv -NoTypeInformation

# how many VMs on each datastore
Get-Datastore | Select-Object Name, Type,
    @{N='VMs';E={(Get-VM -Datastore $_).Count}}

# what each datastore sits on: LUN (VMFS) or server:path (NFS)
Get-Datastore | Select-Object Name, Type, @{N='Backing';E={
    if ($_.Type -eq 'VMFS') { $_.ExtensionData.Info.Vmfs.Extent.DiskName -join ', ' }
    else { "$($_.RemoteHost):$($_.RemotePath)" } }}

# thin over-provisioning: how much is promised vs real capacity
Get-Datastore | Select-Object Name,
    @{N='CapacityGB';E={[math]::Round($_.CapacityGB)}},
    @{N='ProvisionedGB';E={[math]::Round(($_.ExtensionData.Summary.Capacity -
        $_.ExtensionData.Summary.FreeSpace + $_.ExtensionData.Summary.Uncommitted) / 1GB)}},
    @{N='Provisioned%';E={[math]::Round(($_.ExtensionData.Summary.Capacity -
        $_.ExtensionData.Summary.FreeSpace + $_.ExtensionData.Summary.Uncommitted) /
        $_.ExtensionData.Summary.Capacity * 100)}}

# datastore clusters (Storage DRS)
Get-DatastoreCluster | Select-Object Name, CapacityGB, FreeSpaceGB, SdrsAutomationLevel
```

### LUNs and paths

```powershell
# LUNs per host: ID, size, path policy, vendor
Get-VMHost | Get-ScsiLun -LunType disk | Select-Object VMHost, CanonicalName,
    CapacityGB, MultipathPolicy, Vendor |
    Export-Csv -Path C:\Reports\luns.csv -NoTypeInformation

# number of paths per LUN (expect 2+ with iSCSI A/B or dual fabric)
Get-VMHost esx01 | Get-ScsiLun -LunType disk | Select-Object CanonicalName,
    @{N='Paths';E={($_ | Get-ScsiLunPath).Count}}, MultipathPolicy

# every path and its state (Active / Standby / Dead)
Get-VMHost esx01 | Get-ScsiLun -LunType disk | Get-ScsiLunPath |
    Select-Object @{N='LUN';E={$_.ScsiLun.CanonicalName}}, Name, State, Preferred

# DEAD paths only - the one to run when storage misbehaves
Get-VMHost | Get-ScsiLun -LunType disk | Get-ScsiLunPath | Where-Object State -eq 'Dead' |
    Select-Object @{N='Host';E={$_.ScsiLun.VMHost.Name}},
        @{N='LUN';E={$_.ScsiLun.CanonicalName}}, Name

# set Round Robin on LUNs that aren't (check your array vendor's recommendation first)
Get-VMHost esx01 | Get-ScsiLun -LunType disk | Where-Object MultipathPolicy -ne 'RoundRobin' |
    Set-ScsiLun -MultipathPolicy RoundRobin
```

### iSCSI and rescans

```powershell
# iSCSI adapter and its IQN
Get-VMHostHba -VMHost esx01 -Type iScsi | Select-Object Device, IScsiName, Status

# iSCSI targets configured on that adapter
Get-VMHostHba -VMHost esx01 -Type iScsi | Get-IScsiHbaTarget | Select-Object Address, Port, Type

# rescan storage after presenting a new LUN
Get-VMHostStorage -VMHost esx01 -RescanAllHba -RescanVmfs
```

## Terraform-managed VMs

VMs built by Terraform should be changed in Terraform, not here. Changing their
CPU, memory, folder or tags with PowerCLI shows up as drift on the next
`terraform plan`. Use PowerCLI for reports, snapshots, power actions and health checks.

## Linux (lab / automation servers)

Same commands, inside PowerShell 7 (`pwsh`). Install on Ubuntu:

```bash
source /etc/os-release
wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb
sudo apt update && sudo apt install -y powershell
pwsh
```

Then inside `pwsh`: `Install-Module -Name VCF.PowerCLI -Scope CurrentUser`
