# Storage and multipathing

```powershell
Connect-VIServer vcenter.company.local -Credential (Get-Credential)
```

## Datastores (read-only)

```powershell
# size, free space, % free (fullest first)
Get-Datastore | Select-Object Name, Type,
    @{N='CapacityGB';E={[math]::Round($_.CapacityGB)}},
    @{N='FreeGB';E={[math]::Round($_.FreeSpaceGB)}},
    @{N='Free%';E={[math]::Round($_.FreeSpaceGB / $_.CapacityGB * 100)}} |
    Sort-Object 'Free%'

# how many VMs on each datastore
Get-Datastore | Select-Object Name, Type, @{N='VMs';E={(Get-VM -Datastore $_).Count}}

# what each datastore sits on: LUN (VMFS) or server:path (NFS)
Get-Datastore | Select-Object Name, Type, @{N='Backing';E={
    if ($_.Type -eq 'VMFS') { $_.ExtensionData.Info.Vmfs.Extent.DiskName -join ', ' }
    else { "$($_.RemoteHost):$($_.RemotePath)" } }}

# which datastore is on a given LUN
Get-Datastore | Where-Object { $_.ExtensionData.Info.Vmfs.Extent.DiskName -contains 'naa.xxxxxxxx' } |
    Select-Object Name, CapacityGB, FreeSpaceGB

# thin over-provisioning: promised vs real capacity
Get-Datastore | Select-Object Name,
    @{N='CapacityGB';E={[math]::Round($_.CapacityGB)}},
    @{N='ProvisionedGB';E={[math]::Round(($_.ExtensionData.Summary.Capacity -
        $_.ExtensionData.Summary.FreeSpace + $_.ExtensionData.Summary.Uncommitted) / 1GB)}},
    @{N='Provisioned%';E={[math]::Round(($_.ExtensionData.Summary.Capacity -
        $_.ExtensionData.Summary.FreeSpace + $_.ExtensionData.Summary.Uncommitted) /
        $_.ExtensionData.Summary.Capacity * 100)}}

# every VM disk: size, thin/thick, datastore path
Get-VM | Get-HardDisk | Select-Object @{N='VM';E={$_.Parent.Name}},
    Name, CapacityGB, StorageFormat, Filename |
    Export-Csv -Path C:\Reports\vm-disks.csv -NoTypeInformation

# datastore clusters (Storage DRS)
Get-DatastoreCluster | Select-Object Name, CapacityGB, FreeSpaceGB, SdrsAutomationLevel
```

## LUNs and paths (read-only)

`naa.*` = SAN LUNs. `t10.*` / `mpx.*` = local disks (one path, `Fixed` is normal).

```powershell
# LUNs per host: ID, size, path policy, IOPS switching, vendor
Get-VMHost | Where-Object ConnectionState -eq 'Connected' |
    Get-ScsiLun -LunType disk -ErrorAction SilentlyContinue |
    Select-Object VMHost, CanonicalName, CapacityGB, Vendor, Model, MultipathPolicy, CommandsToSwitchPath |
    Export-Csv -Path C:\Reports\luns.csv -NoTypeInformation

# DEAD or non-active paths only: run this when storage misbehaves (no output = all good)
Get-VMHost | Where-Object ConnectionState -eq 'Connected' |
    Get-ScsiLun -LunType disk -ErrorAction SilentlyContinue | Get-ScsiLunPath |
    Where-Object State -ne 'Active' |
    Select-Object @{N='Host';E={$_.ScsiLun.VMHost.Name}},
        @{N='LUN';E={$_.ScsiLun.CanonicalName}}, Name, State

# how many paths each LUN has (expect 2+ with iSCSI A/B or dual fabric)
Get-VMHost | Where-Object ConnectionState -eq 'Connected' | ForEach-Object {
  $h = $_
  Get-ScsiLun -VmHost $h -LunType disk -ErrorAction SilentlyContinue |
    Where-Object CanonicalName -like 'naa.*' | ForEach-Object {
      $paths = Get-ScsiLunPath -ScsiLun $_
      [pscustomobject]@{
        Host   = $h.Name
        LUN    = $_.CanonicalName
        Policy = $_.MultipathPolicy
        Paths  = $paths.Count
        Active = ($paths | Where-Object State -eq 'Active').Count
        Dead   = ($paths | Where-Object State -eq 'Dead').Count
      }
    }
} | Format-Table -AutoSize
```

## Round Robin and IOPS=1 (check before you change)

Many arrays (IBM FlashSystem/SVC, TrueNAS and others) recommend Round Robin with **IOPS=1**:
switch path after every I/O instead of the default 1000. Check your array vendor's current guidance first.
The change is **online**: running VMs are not affected. One host at a time, and set the same LUN
the same way on every host in the cluster.

```powershell
# CHECK one datastore on every host that sees it (read-only)
$ds  = Get-Datastore -Name "DATASTORE_NAME"
$naa = $ds.ExtensionData.Info.Vmfs.Extent.DiskName
$ds | Get-VMHost | Where-Object ConnectionState -eq 'Connected' | ForEach-Object {
    Get-ScsiLun -VmHost $_ -CanonicalName $naa |
        Select-Object @{N='Host';E={$_.VMHost}}, CanonicalName, Vendor, MultipathPolicy, CommandsToSwitchPath
} | Format-Table -AutoSize

# CHECK a few datastores (read-only)
foreach ($name in "DS01","DS02","DS03") {
    $ds  = Get-Datastore -Name $name
    $naa = $ds.ExtensionData.Info.Vmfs.Extent.DiskName
    $ds | Get-VMHost | Where-Object ConnectionState -eq 'Connected' | ForEach-Object {
        Get-ScsiLun -VmHost $_ -CanonicalName $naa |
            Select-Object @{N='Datastore';E={$name}}, @{N='Host';E={$_.VMHost}},
                MultipathPolicy, CommandsToSwitchPath
    }
} | Format-Table -AutoSize

# LIST only non-compliant LUNs of one vendor (no output = all compliant)
Get-VMHost | Where-Object ConnectionState -eq 'Connected' |
    Get-ScsiLun -LunType disk -ErrorAction SilentlyContinue |
    Where-Object { $_.Vendor -eq 'IBM' -and ($_.MultipathPolicy -ne 'RoundRobin' -or $_.CommandsToSwitchPath -ne 1) } |
    Select-Object VMHost, CanonicalName, MultipathPolicy, CommandsToSwitchPath | Sort-Object VMHost

# FIX one LUN on one host (preview, run without -WhatIf, then CHECK again)
Get-ScsiLun -VmHost (Get-VMHost <host-name>) -CanonicalName 'naa.xxxxxxxx' |
    Set-ScsiLun -MultipathPolicy RoundRobin -CommandsToSwitchPath 1 -WhatIf

# FIX all non-compliant LUNs of one vendor on one host (preview first)
Get-VMHost <host-name> | Get-ScsiLun -LunType disk |
    Where-Object { $_.Vendor -eq 'IBM' -and ($_.MultipathPolicy -ne 'RoundRobin' -or $_.CommandsToSwitchPath -ne 1) } |
    Set-ScsiLun -MultipathPolicy RoundRobin -CommandsToSwitchPath 1 -WhatIf

# UNDO (back to the default 1000)
Get-ScsiLun -VmHost (Get-VMHost <host-name>) -CanonicalName 'naa.xxxxxxxx' |
    Set-ScsiLun -CommandsToSwitchPath 1000
```

| MultipathPolicy | CommandsToSwitchPath | Means |
| --- | --- | --- |
| RoundRobin | 1 | already right |
| RoundRobin | 1000 | Round Robin, default switching: set IOPS to 1 |
| Fixed / MostRecentlyUsed | (blank) | not Round Robin at all |

Make **new** LUNs arrive compliant with a claim rule on each host (or in the host profile / vLCM config):

```powershell
$esx = Get-EsxCli -VMHost (Get-VMHost <host-name>) -V2
$esx.storage.nmp.satp.rule.add.Invoke(@{
  satp = 'VMW_SATP_ALUA'; vendor = 'IBM'; model = '2145'
  psp = 'VMW_PSP_RR'; pspoption = 'iops=1'; claimoption = 'tpgs_on'
  description = 'IBM FlashSystem RR iops=1'
})
```

Equivalent on the host: `esxcli storage nmp psp roundrobin deviceconfig set -d naa.xxxxxxxx -t iops -I 1`

## iSCSI and rescans

```powershell
# iSCSI adapter and its IQN (the name the array's ACL uses)
Get-VMHost | Where-Object ConnectionState -eq 'Connected' | Get-VMHostHba -Type IScsi |
    Select-Object VMHost, Device, IScsiName, Status

# iSCSI targets on that adapter
Get-VMHostHba -VMHost esx02 -Type IScsi | Get-IScsiHbaTarget | Select-Object Address, Port, Type, IScsiName

# all storage adapters (FC shows the WWN in NodeWorldWideName / PortWorldWideName)
Get-VMHost | Where-Object ConnectionState -eq 'Connected' | Get-VMHostHba |
    Select-Object VMHost, Device, Type, Model, Status

# rescan after presenting or removing a LUN
Get-VMHost | Where-Object ConnectionState -eq 'Connected' | Get-VMHostStorage -RescanAllHba -RescanVmfs
```
