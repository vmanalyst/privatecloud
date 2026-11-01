# NSX (read-only checks)

NSX has its own manager and its own login. This file uses the **NSX REST API** from PowerShell 7
(`Invoke-RestMethod`). That works on every NSX version and needs no extra module.
Everything here only **reads** (`GET`).

> NSX changes (segments, firewall rules, gateways) belong in the NSX UI, or in Terraform with the
> NSX provider, not in ad-hoc scripts.

## Connect

```powershell
$nsx  = "https://nsx-manager.company.local"
$cred = Get-Credential                     # NSX admin or an audit account

# one small helper so each check is one line
function Get-Nsx($path) {
    Invoke-RestMethod -Uri "$nsx$path" -Authentication Basic -Credential $cred -SkipCertificateCheck
}
```

`-SkipCertificateCheck` is for labs with self-signed certificates. Remove it where NSX has a proper certificate.

## Manager cluster health

```powershell
$status = Get-Nsx "/api/v1/cluster/status"
$status.mgmt_cluster_status.status          # STABLE = good
$status.control_cluster_status.status       # STABLE = good
$status.detailed_cluster_status.groups | Select-Object group_type, group_status
```

## Open alarms

```powershell
(Get-Nsx "/api/v1/alarms?status=OPEN").results |
    Select-Object severity, feature_name, event_type, entity_id,
        @{N='Since';E={[DateTimeOffset]::FromUnixTimeMilliseconds($_.last_reported_time).LocalDateTime}} |
    Sort-Object severity
```

## Segments (the NSX networks VMs plug into)

```powershell
(Get-Nsx "/policy/api/v1/infra/segments").results |
    Select-Object display_name,
        @{N='Subnet';E={$_.subnets.gateway_address -join ', '}},
        @{N='VLAN';E={$_.vlan_ids -join ', '}},
        @{N='Gateway';E={($_.connectivity_path -split '/')[-1]}},
        @{N='TransportZone';E={($_.transport_zone_path -split '/')[-1]}} |
    Sort-Object display_name | Format-Table -AutoSize
```

In vCenter the same segments show up as networks: `Get-VirtualNetwork | Where-Object NetworkType -eq 'Opaque'`
(or as distributed port groups on VDS 7+).

## Gateways (Tier-0 and Tier-1 routers)

```powershell
(Get-Nsx "/policy/api/v1/infra/tier-0s").results | Select-Object display_name, ha_mode
(Get-Nsx "/policy/api/v1/infra/tier-1s").results |
    Select-Object display_name, @{N='Tier0';E={($_.tier0_path -split '/')[-1]}}
```

## Transport nodes (ESXi hosts and Edges prepared for NSX)

```powershell
$nodes = (Get-Nsx "/api/v1/transport-nodes").results
$nodes | ForEach-Object {
    $state = Get-Nsx "/api/v1/transport-nodes/$($_.id)/state"
    [pscustomobject]@{
        Name  = $_.display_name
        Type  = $_.node_deployment_info.resource_type      # HostNode / EdgeNode
        State = $state.state                               # success = good
        Status = $state.node_deployment_state.state
    }
} | Sort-Object Type, Name | Format-Table -AutoSize

# tunnel status per node (UP = good)
$nodes | ForEach-Object {
    $t = Get-Nsx "/api/v1/transport-nodes/$($_.id)/status"
    [pscustomobject]@{ Name = $_.display_name; Tunnels = $t.tunnel_status.status;
                       Up = $t.tunnel_status.up_count; Down = $t.tunnel_status.down_count }
} | Format-Table -AutoSize
```

## Distributed firewall: policies and groups

```powershell
# security policies (sections) and how many rules each has
(Get-Nsx "/policy/api/v1/infra/domains/default/security-policies").results |
    Select-Object display_name, category, sequence_number,
        @{N='Rules';E={(Get-Nsx "/policy/api/v1/infra/domains/default/security-policies/$($_.id)/rules").result_count}} |
    Sort-Object category, sequence_number

# groups (used in firewall rules)
(Get-Nsx "/policy/api/v1/infra/domains/default/groups").results |
    Select-Object display_name, description | Sort-Object display_name
```

## Export for an audit

Add to the end of any of the lines above:

```powershell
| Export-Csv -Path C:\Reports\nsx-segments.csv -NoTypeInformation
```

## If a call fails

| Error | Usually means |
| --- | --- |
| 401 Unauthorized | wrong user or password, or the account is locked |
| 403 Forbidden | the account's NSX role can't read that area |
| 404 Not Found | path differs on your NSX version: check the API guide for your version |
| certificate error | add `-SkipCertificateCheck` (lab only) |
