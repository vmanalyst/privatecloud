# Networks

```powershell
Connect-VIServer vcenter.company.local -Credential (Get-Credential)
```

## Standard switches (read-only)

```powershell
# port groups on every host
Get-VMHost | Where-Object ConnectionState -eq 'Connected' |
    Get-VirtualPortGroup -Standard |
    Select-Object VMHost, Name, VLanId, VirtualSwitchName |
    Sort-Object Name, VMHost | Format-Table -AutoSize

# consistency check: port groups missing on some hosts (no output = all consistent)
$hosts = Get-VMHost | Where-Object ConnectionState -eq 'Connected'
Get-VirtualPortGroup -VMHost $hosts -Standard | Group-Object Name |
    Select-Object Name, Count, @{N='MissingOn';E={
        $have = $_.Group.VMHost.Name
        ($hosts.Name | Where-Object { $_ -notin $have }) -join ', ' }} |
    Where-Object Count -lt $hosts.Count

# physical uplinks: speed and link
Get-VMHost | Where-Object ConnectionState -eq 'Connected' |
    Get-VMHostNetworkAdapter -Physical |
    Select-Object VMHost, Name, BitRatePerSec, FullDuplex, Mac | Format-Table -AutoSize
```

A port group missing (or named differently) on one host breaks vMotion and causes `NoCompatibleHost`.

## VMkernel adapters (the hosts' own IPs)

```powershell
Get-VMHost | Where-Object ConnectionState -eq 'Connected' |
    Get-VMHostNetworkAdapter -VMKernel |
    Select-Object VMHost, Name, IP, SubnetMask, PortGroupName, Mtu,
        VMotionEnabled, ManagementTrafficEnabled, VsanTrafficEnabled |
    Format-Table -AutoSize
```

Check that `Mtu` is the same on every host for vMotion, vSAN and iSCSI (usually 9000 or 1500).

## VM network adapters

```powershell
# which VM is on which network
Get-VM | Get-NetworkAdapter |
    Select-Object @{N='VM';E={$_.Parent}}, Name, NetworkName, Type, MacAddress, ConnectionState |
    Sort-Object NetworkName | Format-Table -AutoSize

# NICs not connected (often a mistake after a clone)
Get-VM | Get-NetworkAdapter | Where-Object { -not $_.ConnectionState.Connected } |
    Select-Object @{N='VM';E={$_.Parent}}, Name, NetworkName

# old E1000 adapters (should be VMXNET3)
Get-VM | Get-NetworkAdapter | Where-Object Type -ne 'Vmxnet3' |
    Select-Object @{N='VM';E={$_.Parent}}, Name, Type
```

## Add / remove a port group (changes)

```powershell
# add VLAN 1620 to every host in a cluster (preview first)
Get-Cluster Cluster01 | Get-VMHost | Where-Object ConnectionState -eq 'Connected' |
    Get-VirtualSwitch -Standard -Name vSwitch0 |
    New-VirtualPortGroup -Name "VM-1620-test" -VLanId 1620 -WhatIf

# remove it from every host
Get-VirtualPortGroup -Name "VM-1620-test" | Remove-VirtualPortGroup -Confirm:$false -WhatIf
```

## Distributed switches (read-only)

```powershell
Get-VDSwitch | Select-Object Name, Version, Mtu, NumUplinkPorts
Get-VDPortgroup | Select-Object Name, VDSwitch, VlanConfiguration, NumPorts | Sort-Object Name

# which hosts are on each distributed switch
Get-VDSwitch | Select-Object Name, @{N='Hosts';E={(Get-VMHost -DistributedSwitch $_).Name -join ', '}}
```

NSX segments appear in vCenter as networks too: `Get-VirtualNetwork | Select-Object Name, NetworkType`. For NSX itself, see 06-nsx.md.
