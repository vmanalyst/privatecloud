# PowerCLI guide

Everyday vSphere tasks from the command line, one file per topic.
Start here: install, connect and the golden rules. Then open the file you need.

| File | What's in it |
| --- | --- |
| [01-vms.md](01-vms.md) | VM reports, power, snapshots, move, notes, tags |
| [02-hosts.md](02-hosts.md) | ESXi inventory, NTP, SSH, maintenance mode, advanced settings, esxcli |
| [03-networks.md](03-networks.md) | port groups, consistency check, VMkernel, VM NICs, distributed switches |
| [04-storage.md](04-storage.md) | datastores, LUNs, paths, Round Robin IOPS=1, iSCSI, rescans |
| [05-vsan.md](05-vsan.md) | vSAN health, capacity, resync, disks, policies, maintenance mode |
| [06-nsx.md](06-nsx.md) | NSX read-only checks: manager, segments, gateways, transport nodes, alarms |
| [07-health.md](07-health.md) | morning checks: alarms, Tools, space, snapshots, CD-ROMs, HA/DRS |
| [08-permissions.md](08-permissions.md) | permission and role audits, least-privilege Terraform role |
| [09-reports.md](09-reports.md) | CSV export, saved login, weekly report script, Task Scheduler |
| [weekly-report.ps1](weekly-report.ps1) | the ready-to-run weekly report (read-only) |

## Install (Windows)

Use **PowerShell 7** (`pwsh`). PowerCLI does not run in the old Command Prompt (`cmd`).

```powershell
# PowerShell 7, once (admin command prompt)
winget install --id Microsoft.PowerShell -e

# allow locally created scripts to run (once, for your user)
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# install PowerCLI (VCF 9 name: VCF.PowerCLI)
Install-Module -Name VCF.PowerCLI -Scope CurrentUser

# remove the old module if it is still there, so the two don't clash
Get-Module -ListAvailable VMware.PowerCLI
Uninstall-Module VMware.PowerCLI -AllVersions

# check the version / update later
Get-Module -ListAvailable VCF.PowerCLI | Select-Object Name, Version
Update-Module VCF.PowerCLI

# lab/self-signed certificates and no telemetry prompt
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCEIP $false -Scope User -Confirm:$false
```

### No internet on the jump server?

On a machine **with** internet: `Save-Module -Name VCF.PowerCLI -Path C:\Temp\PowerCLI`

Copy the contents to `C:\Program Files\PowerShell\Modules` on the jump server, then:

```powershell
Get-ChildItem "C:\Program Files\PowerShell\Modules" -Recurse | Unblock-File
Get-Module -Name VCF.PowerCLI -ListAvailable
```

## Connect / disconnect

```powershell
Connect-VIServer vcenter.company.local -Credential (Get-Credential)
Disconnect-VIServer -Confirm:$false
```

## Golden rules (read before changing anything)

| Starts with | Does | Risk |
| --- | --- | --- |
| `Get-`, `Test-` | only reads and shows | none, safe on live systems |
| `Set-`, `New-`, `Remove-`, `Stop-`, `Start-`, `Move-` | changes something | needs care |

- **`-WhatIf` first.** It lists what *would* happen and does nothing. Read it, then run without it.
- **Skip hosts that aren't connected:** `Get-VMHost | Where-Object ConnectionState -eq 'Connected'`.
- **One host at a time** for changes, then check, then the next.
- **Save a before and after CSV** for the change ticket.
- **Compare with the vSphere Client** the first few times, until you trust the output.

```text
Get-…  (look) → Where-Object (filter) → Sort-Object → Select-Object (columns)
Get-…  → Set-/New-/Remove-… -WhatIf (preview) → run for real → Get-… again (verify)
```

`@{N='Name';E={ ... }}` inside `Select-Object` is a **calculated column**: N is the column name, E is the sum.
`[pscustomobject]@{ ... }` builds your own report row.

## Terraform-managed VMs

VMs built by Terraform should be changed in Terraform, not with PowerCLI. Changing their
CPU, memory, disks, NICs, folder or tags here shows up as drift on the next `terraform plan`.
Use PowerCLI for reports, snapshots, power actions and health checks.

## Keep scripts in Git (Windows)

```powershell
cd C:\privatecloud
git pull                                # always first
git add -A; git commit -m "powercli: ..."; git push
```

First-time setup (once per PC):

```powershell
winget install --id Git.Git -e          # then open a new window
git config --global user.name  "vmanalyst"
git config --global user.email "<id>+vmanalyst@users.noreply.github.com"   # github.com/settings/emails
ssh-keygen -t ed25519 -C "windows-pc"
Get-Content $HOME\.ssh\id_ed25519.pub   # add at github.com/settings/keys
ssh -T git@github.com
git clone git@github.com:vmanalyst/privatecloud.git C:\privatecloud
```

If `git` is "not recognized" but `C:\Program Files\Git\cmd\git.exe` exists, add that folder to your user PATH and open a new window.

## Linux (lab / automation servers)

```bash
source /etc/os-release
wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb
sudo apt update && sudo apt install -y powershell
pwsh
```

Then inside `pwsh`: `Install-Module -Name VCF.PowerCLI -Scope CurrentUser`
