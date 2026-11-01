# Connecting and authentication

How you log in to vCenter with PowerCLI: typed by hand, or with a saved login.
Run everything in **PowerShell 7** (`pwsh`), one command per line.


## Quick: one vCenter, type the password

```powershell
Connect-VIServer vcenter.lab.internal -Credential (Get-Credential)
Disconnect-VIServer * -Confirm:$false
```

Use this on a jump server you don't own, or with a vault (CyberArk) password.

## Saved logins: the credential store

PowerCLI can remember a login for each vCenter, so you never type the password again on that PC.

**How it works**

- `New-VICredentialStoreItem` saves vCenter name + user + password into one file:
  `C:\Users\<you>\AppData\Roaming\VMware\credstore\vicredentials.xml`
- The password in that file is **encrypted by Windows** for **your** Windows login on **this** PC.
  Copied to another PC or another user, it can't be read. That is deliberate.
- `Connect-VIServer <name>` looks in that file by itself. If the name is there, no password is asked.
- The file is outside the Git folder, so it is never pushed.

**Save a login (once per vCenter, per PC)**

```powershell
New-VICredentialStoreItem -Host vcenter.lab.internal -User svc-automation@vsphere.local -Password (Read-Host "Password")
```

Run it on its own line: `Read-Host` waits for you to type the password.

**Connect**

```powershell
Connect-VIServer vcenter.lab.internal                                   # one
Connect-VIServer vcenter.lab.internal, vcenter2.lab.internal            # several
C:\Scripts\powercli\connect.ps1                                         # menu: vCenter, then cluster
```

`connect.ps1` lists every saved vCenter as 1, 2, 3, connects to the one you pick, then lists its
clusters (Enter = all). It sets `$cluster`, so commands can use `-Location $cluster`.
Run it again to switch. Close the window to finish.

**Manage saved logins**

| To | Command |
| --- | --- |
| see what's saved | `Get-VICredentialStoreItem` |
| password changed | run `New-VICredentialStoreItem` again for that vCenter (overwrites) |
| remove one | `Remove-VICredentialStoreItem -Host vcenter.lab.internal -Confirm:$false` |
| new PC | save each login again on that PC (the file doesn't move with you) |

**Rules**

- Never put a password inside a script, and never commit the credential file.
- Saved logins are fine for your own PC and for scheduled reports (save them **as the account that runs the task**).
- In a bank or audited site, use your own named admin account or the vault, typed each time.

## What connect.ps1 does, line by line

```powershell
Disconnect-VIServer * -Confirm:$false -ErrorAction SilentlyContinue   # drop any old connection
$vcs = @(Get-VICredentialStoreItem | Sort-Object Host)                 # read your saved logins
# ... shows them as [1] [2] [3], you type a number ...
Connect-VIServer $vcs[$n - 1].Host                                     # connect: password comes from the store
$all = @(Get-Cluster | Sort-Object Name)                               # list the clusters
# ... shows them as [1] [2], you type a number or press Enter ...
$global:cluster = ...                                                  # $cluster = your pick (or all)
```

It never sees or prints a password: `Connect-VIServer` gets it from the store by itself.

## Check your setup (when something won't run)

All read-only. Run them one by one and compare with the "good" column.

```powershell
$PSVersionTable.PSVersion
Get-ExecutionPolicy -List
Get-Command Connect-VIServer
Get-Module -ListAvailable VCF.PowerCLI | Select-Object Name, Version
Get-ChildItem C:\Scripts\powercli
Get-VICredentialStoreItem
$global:DefaultVIServers
```

| Command | Good | If not |
| --- | --- | --- |
| `$PSVersionTable.PSVersion` | Major **7** | type `pwsh` first (5 = the old PowerShell) |
| `Get-ExecutionPolicy -List` | CurrentUser **RemoteSigned**, MachinePolicy/UserPolicy **Undefined** | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. AllSigned under MachinePolicy = company policy: scripts must be signed |
| `Get-Command Connect-VIServer` | shows the command | PowerCLI isn't installed in this PowerShell: `Install-Module VCF.PowerCLI -Scope CurrentUser` |
| `Get-Module -ListAvailable VCF.PowerCLI` | a version (9.x) | same as above |
| `Get-ChildItem C:\Scripts\powercli` | `connect.ps1` is there | copy it in, then `Unblock-File` it |
| `Get-VICredentialStoreItem` | your vCenter(s) and user | save one with `New-VICredentialStoreItem` |
| `$global:DefaultVIServers` | the vCenter you're connected to | nothing = not connected: run `connect.ps1` |

## Common errors

| Error | Means | Fix |
| --- | --- | --- |
| `Cannot complete login due to an incorrect user name or password` | saved password is old | run `New-VICredentialStoreItem` again for that vCenter |
| menu shows nothing to pick | no saved logins on this PC / user | save one with `New-VICredentialStoreItem` |
| `is not digitally signed` | file downloaded from the internet | `Unblock-File C:\Scripts\powercli\connect.ps1` |
| `DirectoryNotFoundException` with `-File` | your own creds folder doesn't exist | `New-Item -ItemType Directory C:\Scripts\creds -Force` |
| `The term 'Connect-VIServer' is not recognized` | you're in the old PowerShell 5 | type `pwsh` first |
| certificate error | lab self-signed certificate | `Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope User -Confirm:$false` |
