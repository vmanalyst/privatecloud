# connect.ps1 - pick a vCenter, pick a cluster. Run again to switch.

Disconnect-VIServer * -Confirm:$false -ErrorAction SilentlyContinue

# 1. vCenter (from your saved logins)
$vcs = @(Get-VICredentialStoreItem | Sort-Object Host)
for ($i = 0; $i -lt $vcs.Count; $i++) { Write-Host "  [$($i + 1)] $($vcs[$i].Host)" }
$n = Read-Host "vCenter number"
Connect-VIServer $vcs[$n - 1].Host | Out-Null
Write-Host "Connected: $($vcs[$n - 1].Host)" -ForegroundColor Green

# 2. cluster (Enter = all)
$all = @(Get-Cluster | Sort-Object Name)
for ($i = 0; $i -lt $all.Count; $i++) { Write-Host "  [$($i + 1)] $($all[$i].Name)" }
$c = Read-Host "Cluster number (Enter = all)"
if ($c) { $global:cluster = $all[$c - 1] } else { $global:cluster = $all }
Write-Host "Cluster: $($global:cluster.Name -join ', ')" -ForegroundColor Green
