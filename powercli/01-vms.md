# VMs

```powershell
Connect-VIServer vcenter.company.local -Credential (Get-Credential)
```

## Reports (read-only)

```powershell
# name, power, CPU, RAM, IP, folder
Get-VM | Select-Object Name, PowerState, NumCpu, MemoryGB,
    @{N='IP';E={$_.Guest.IPAddress -join ','}},
    @{N='Folder';E={$_.Folder.Name}} | Sort-Object Name

# powered-on VMs only
Get-VM | Where-Object PowerState -eq 'PoweredOn' | Sort-Object Name |
    Select-Object Name, NumCpu, MemoryGB

# guest OS, hardware version, host and cluster
Get-VM | Select-Object Name, HardwareVersion,
    @{N='GuestOS';E={$_.Guest.OSFullName}},
    @{N='Host';E={$_.VMHost.Name}},
    @{N='Cluster';E={$_.VMHost.Parent.Name}} | Sort-Object Cluster, Name

# the 10 biggest VMs by disk
Get-VM | Select-Object Name, @{N='ProvisionedGB';E={[math]::Round($_.ProvisionedSpaceGB)}} |
    Sort-Object ProvisionedGB -Descending | Select-Object -First 10

# VM folders as full paths
Get-Folder -Type VM | Where-Object Name -ne 'vm' | ForEach-Object {
    $path = $_.Name; $p = $_.Parent
    while ($p -and $p.Name -ne 'vm') { $path = "$($p.Name)/$path"; $p = $p.Parent }
    $path
} | Sort-Object
```

## Power

```powershell
Get-VM new-app-01 | Stop-VMGuest -WhatIf               # preview
Get-VM new-app-01 | Stop-VMGuest -Confirm:$false      # clean OS shutdown, via VMware Tools
Get-VM new-app-01 | Start-VM                          # power on
Get-VM new-app-01 | Restart-VMGuest -Confirm:$false   # clean restart
Get-VM new-app-01 | Stop-VM -Confirm:$false           # hard power off: only if the guest is hung
```

## Snapshots

```powershell
Get-VM new-app-01 | New-Snapshot -Name "pre-patch" -Description "Before patching"

# every VM in a folder, in one go (preview first)
Get-VM -Location "Marketing" | New-Snapshot -Name "pre-patch" -WhatIf

# all snapshots, with age and size, oldest first
Get-VM | Get-Snapshot | Select-Object VM, Name, Created,
    @{N='SizeGB';E={[math]::Round($_.SizeGB, 1)}},
    @{N='AgeDays';E={((Get-Date) - $_.Created).Days}} |
    Sort-Object AgeDays -Descending

# remove one snapshot (check the name first!)
Get-Snapshot -VM web01 -Name "pre-patch" | Remove-Snapshot -Confirm:$false

# remove snapshots older than 7 days: ALWAYS -WhatIf first, read the list, then without it
Get-VM | Get-Snapshot | Where-Object { $_.Created -lt (Get-Date).AddDays(-7) } | Remove-Snapshot -WhatIf
```

## Move a VM, and notes

```powershell
$folder = Get-Folder -Name "Apps" -Location (Get-Folder -Name "Banking")
Move-VM -VM web01 -InventoryLocation $folder

# notes on many VMs at once (preview first)
Get-VM -Location "Banking" | Set-VM -Notes "Owner: Banking team" -Confirm:$false -WhatIf
```

## Tags

```powershell
Get-TagAssignment -Entity (Get-VM web01)                              # show tags
New-TagAssignment -Tag (Get-Tag -Name "Prod") -Entity (Get-VM web01)  # add a tag
Get-VM -Tag "Prod"                                                    # all VMs with a tag
```

> Terraform-built VMs: change CPU, RAM, disks, folder and tags in Terraform, not here.
