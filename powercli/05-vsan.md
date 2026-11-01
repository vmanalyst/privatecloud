# vSAN

```powershell
Connect-VIServer vcenter.company.local -Credential (Get-Credential)
$cluster = Get-Cluster "Cluster01"
```

Everything here is read-only except the maintenance mode section at the end.
**OSA** = original architecture (disk groups: cache + capacity disks).
**ESA** = Express Storage Architecture, vSAN 8+ (storage pool, NVMe only, no disk groups).

## Is vSAN on, and how is it set up?

```powershell
Get-Cluster | Select-Object Name, VsanEnabled

Get-VsanClusterConfiguration -Cluster $cluster |
    Select-Object Cluster, VsanEnabled, SpaceEfficiencyEnabled, StretchedClusterEnabled,
        PerformanceServiceEnabled, HealthCheckEnabled
```

## Health

```powershell
# full health test (takes a minute; same as Monitor > vSAN > Skyline Health)
$health = Test-VsanClusterHealth -Cluster $cluster
$health.OverallHealthStatus           # green / yellow / red

# only the tests that are not green
$health.TestResult | Where-Object { $_.TestHealth -ne 'green' } |
    Select-Object TestGroupName, TestName, TestHealth
```

If the property names differ on your version, run `$health | Format-List *` to see them.

## Capacity

```powershell
Get-VsanSpaceUsage -Cluster $cluster |
    Select-Object @{N='CapacityGB';E={[math]::Round($_.CapacityGB)}},
        @{N='FreeGB';E={[math]::Round($_.FreeSpaceGB)}},
        @{N='Free%';E={[math]::Round($_.FreeSpaceGB / $_.CapacityGB * 100)}}

# the vSAN datastore as a normal datastore
Get-Datastore -RelatedObject $cluster | Where-Object Type -eq 'vsan' |
    Select-Object Name, CapacityGB, FreeSpaceGB
```

Keep **about 25–30% free** (slack space) so rebuilds and policy changes can finish.

## Resync: is data still moving?

```powershell
# no output = nothing resyncing (safe to do the next host)
Get-VsanResyncingComponent -Cluster $cluster |
    Select-Object VM, Name, @{N='GBLeft';E={[math]::Round($_.BytesToSyncGB, 1)}}
```

Always check this is empty **before** putting the next host into maintenance mode.

## Disks

```powershell
# OSA: disk groups per host, and the disks in them
Get-VsanDiskGroup -Cluster $cluster | Select-Object VMHost, Name, DiskGroupType
Get-VsanDiskGroup -Cluster $cluster | Get-VsanDisk |
    Select-Object @{N='Host';E={$_.VsanDiskGroup.VMHost}}, CanonicalName, IsCacheDisk, IsSsd,
        @{N='CapacityGB';E={[math]::Round($_.CapacityGB)}}

# ESA: storage pool disks, through esxcli on each host
Get-VMHost -Location $cluster | Where-Object ConnectionState -eq 'Connected' | ForEach-Object {
    $esx = Get-EsxCli -VMHost $_ -V2
    $esx.vsan.storagepool.list.Invoke() | Select-Object @{N='Host';E={$_.VMHost}}, *
}

# any host: vSAN networking (which vmk carries vSAN traffic)
Get-VMHost -Location $cluster | Where-Object ConnectionState -eq 'Connected' |
    Get-VMHostNetworkAdapter -VMKernel | Where-Object VsanTrafficEnabled |
    Select-Object VMHost, Name, IP, Mtu
```

## Fault domains

```powershell
Get-VsanFaultDomain -Cluster $cluster | Select-Object Name, @{N='Hosts';E={$_.VMHost.Name -join ', '}}
```

## Storage policies and compliance

```powershell
# vSAN policies
Get-SpbmStoragePolicy | Where-Object { $_.AnyOfRuleSets.AllOfRules.Capability.Name -like 'VSAN*' } |
    Select-Object Name, Description

# VMs that are NOT compliant with their policy
Get-VM -Location $cluster | Get-SpbmEntityConfiguration |
    Where-Object ComplianceStatus -ne 'compliant' |
    Select-Object Entity, StoragePolicy, ComplianceStatus

# which policy each VM uses
Get-VM -Location $cluster | Get-SpbmEntityConfiguration |
    Select-Object Entity, StoragePolicy | Sort-Object StoragePolicy
```

## Maintenance mode on vSAN (a change)

The extra option says what happens to the data on that host:

| VsanDataMigrationMode | Means | Use for |
| --- | --- | --- |
| `EnsureAccessibility` | moves only what's needed so VMs stay up | patching, reboots (normal choice) |
| `Full` | moves all data off the host | removing or rebuilding the host |
| `NoDataMigration` | moves nothing | only if you know the data is protected elsewhere |

```powershell
# 1. nothing resyncing?
Get-VsanResyncingComponent -Cluster $cluster

# 2. enter (preview first)
Get-VMHost esx01* | Set-VMHost -State Maintenance -Evacuate -VsanDataMigrationMode EnsureAccessibility -WhatIf

# 3. after patching, exit, then wait for resync to finish before the next host
Get-VMHost esx01* | Set-VMHost -State Connected -WhatIf
```
