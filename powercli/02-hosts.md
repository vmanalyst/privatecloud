# Hosts (ESXi)

```powershell
Connect-VIServer vcenter.company.local -Credential (Get-Credential)
```

## Inventory (read-only)

```powershell
# state, version and build (mismatched builds in a cluster = a host missed in patching)
Get-VMHost | Select-Object Name, ConnectionState, PowerState, Version, Build,
    @{N='Cluster';E={$_.Parent}}, Model, NumCpu,
    @{N='MemGB';E={[math]::Round($_.MemoryTotalGB)}} | Format-Table -AutoSize

# CPU and memory use
Get-VMHost | Select-Object Name, ConnectionState,
    @{N='CPU%';E={[math]::Round($_.CpuUsageMhz / $_.CpuTotalMhz * 100)}},
    @{N='Mem%';E={[math]::Round($_.MemoryUsageGB / $_.MemoryTotalGB * 100)}}

# how many VMs on each host
Get-VMHost | Select-Object Name, @{N='VMs';E={($_ | Get-VM).Count}}

# hardware: vendor, serial number, BIOS
Get-VMHost | Where-Object ConnectionState -eq 'Connected' | Select-Object Name,
    @{N='Vendor';E={$_.ExtensionData.Hardware.SystemInfo.Vendor}},
    @{N='Serial';E={($_.ExtensionData.Hardware.SystemInfo.OtherIdentifyingInfo |
        Where-Object { $_.IdentifierType.Key -eq 'SerialNumberTag' }).IdentifierValue}},
    @{N='BIOS';E={$_.ExtensionData.Hardware.BiosInfo.BiosVersion}}
```

## NTP

```powershell
# check: servers and whether the service runs
Get-VMHost | Where-Object ConnectionState -eq 'Connected' | Select-Object Name,
    @{N='NTPServers';E={(Get-VMHostNtpServer -VMHost $_) -join ', '}},
    @{N='NTPRunning';E={(Get-VMHostService -VMHost $_ | Where-Object Key -eq 'ntpd').Running}}

# set on all hosts (preview first)
Get-VMHost | Where-Object ConnectionState -eq 'Connected' | ForEach-Object {
    Add-VMHostNtpServer -VMHost $_ -NtpServer 172.16.11.5 -WhatIf
    Get-VMHostService -VMHost $_ | Where-Object Key -eq 'ntpd' | Set-VMHostService -Policy On -WhatIf
    Get-VMHostService -VMHost $_ | Where-Object Key -eq 'ntpd' | Start-VMHostService -WhatIf
}
```

## SSH

```powershell
# who left it on?
Get-VMHost | Where-Object ConnectionState -eq 'Connected' | Get-VMHostService |
    Where-Object Key -eq 'TSM-SSH' | Select-Object VMHost, Running, Policy

# turn it off everywhere (preview first)
Get-VMHost | Where-Object ConnectionState -eq 'Connected' | Get-VMHostService |
    Where-Object { $_.Key -eq 'TSM-SSH' -and $_.Running } | Stop-VMHostService -Confirm:$false -WhatIf
```

## Maintenance mode and reconnect

```powershell
# enter: DRS moves the VMs off first (needs DRS fully automated and spare hosts)
Get-VMHost esx01* | Set-VMHost -State Maintenance -Evacuate -WhatIf
# exit
Get-VMHost esx01* | Set-VMHost -State Connected -WhatIf

# vSAN clusters: see 05-vsan.md (needs -VsanDataMigrationMode)

# reconnect a host that shows Not responding
Get-VMHost 172.16.11.104 | Set-VMHost -State Connected
```

## Advanced settings

```powershell
# where logs go
Get-VMHost | Where-Object ConnectionState -eq 'Connected' |
    Get-AdvancedSetting -Name 'Syslog.global.logHost' | Select-Object Entity, Name, Value

# compare one setting across every host (spot the odd one out)
Get-VMHost | Where-Object ConnectionState -eq 'Connected' |
    Get-AdvancedSetting -Name 'UserVars.SuppressShellWarning' | Select-Object Entity, Value
```

## esxcli without SSH

```powershell
$esx = Get-EsxCli -VMHost (Get-VMHost esx02*) -V2
$esx.system.version.get.Invoke()
$esx.network.nic.list.Invoke() | Select-Object Name, LinkStatus, Speed, Driver
$esx.storage.nmp.device.list.Invoke() | Select-Object Device, PathSelectionPolicy, WorkingPaths
```

`Get-EsxCli` runs the same commands as `esxcli` on the host. Lists are safe; `set`/`add`/`remove` change things.
