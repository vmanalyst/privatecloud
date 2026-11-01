# Permissions and roles

```powershell
Connect-VIServer vcenter.company.local -Credential (Get-Credential)
```

A permission is three things: a **role** (a set of privileges), a **principal** (user or group), and the **object** it applies to.

## Audit exports (read-only)

```powershell
# ALL permissions: who, which role, on what, does it propagate
Get-VIPermission | Select-Object @{N='Object';E={$_.Entity.Name}},
    @{N='ObjectType';E={$_.EntityId.Split('-')[0]}},
    Principal, Role, Propagate, IsGroup |
    Export-Csv -Path C:\Reports\vcenter-permissions.csv -NoTypeInformation

# permissions on one folder / one VM
Get-VIPermission -Entity (Get-Folder -Name "Banking") | Select-Object Principal, Role, Propagate, IsGroup
Get-VIPermission -Entity (Get-VM web01) | Select-Object Principal, Role, Propagate

# every folder with its permissions, in one CSV
Get-Folder -Type VM | Where-Object Name -ne 'vm' | ForEach-Object {
    $folder = $_
    Get-VIPermission -Entity $folder | Select-Object @{N='Folder';E={$folder.Name}},
        Principal, Role, Propagate, IsGroup
} | Export-Csv -Path C:\Reports\folder-permissions.csv -NoTypeInformation

# who has Admin anywhere (the list auditors ask for)
Get-VIPermission | Where-Object Role -eq 'Admin' | Select-Object Principal, @{N='Object';E={$_.Entity.Name}}, IsGroup

# individual users with permissions (should be groups instead)
Get-VIPermission | Where-Object { -not $_.IsGroup } | Select-Object Principal, Role, @{N='Object';E={$_.Entity.Name}}

# all roles and their privileges
Get-VIRole | Select-Object Name, IsSystem, @{N='Privileges';E={$_.PrivilegeList -join '; '}} |
    Export-Csv -Path C:\Reports\vcenter-roles.csv -NoTypeInformation

# only custom roles (the ones your team created)
Get-VIRole | Where-Object IsSystem -eq $false | Select-Object Name
```

## Grant access to a folder (a change)

```powershell
New-VIPermission -Entity (Get-Folder -Name "Banking") `
    -Principal "CORP\Banking-VM-Admins" -Role "Virtual machine user" -Propagate:$true -WhatIf
```

`-Propagate:$true` = also applies to every subfolder and VM inside. Prefer AD **groups** over users.

## Copy a role (backup before editing it)

```powershell
New-VIRole -Name "Automation-Backup" -Privilege (Get-VIPrivilege -Role "Automation-Packer-Terraform")
```

## A least-privilege role for Terraform

```powershell
$privs = Get-VIPrivilege -Id @(
  'System.Anonymous','System.View','System.Read',
  'VirtualMachine.Inventory.Create','VirtualMachine.Inventory.CreateFromExisting','VirtualMachine.Inventory.Delete',
  'VirtualMachine.Provisioning.Clone','VirtualMachine.Provisioning.DeployTemplate','VirtualMachine.Provisioning.Customize','VirtualMachine.Provisioning.ReadCustSpecs',
  'VirtualMachine.Config.AddNewDisk','VirtualMachine.Config.AddRemoveDevice','VirtualMachine.Config.CPUCount','VirtualMachine.Config.Memory',
  'VirtualMachine.Config.DiskExtend','VirtualMachine.Config.EditDevice','VirtualMachine.Config.Settings','VirtualMachine.Config.Annotation',
  'VirtualMachine.Interact.PowerOn','VirtualMachine.Interact.PowerOff',
  'Resource.AssignVMToPool','Datastore.AllocateSpace','Datastore.Browse','Network.Assign',
  'Folder.Create','InventoryService.Tagging.AttachTag','InventoryService.Tagging.CreateTag','InventoryService.Tagging.CreateCategory',
  'ContentLibrary.ReadStorage','ContentLibrary.DownloadSession'
)
New-VIRole -Name "Terraform-Provisioner" -Privilege $privs -WhatIf

New-VIPermission -Entity (Get-Datacenter DC1) -Principal "VSPHERE.LOCAL\svc-automation" `
    -Role "Terraform-Provisioner" -Propagate:$true -WhatIf
```

If a privilege ID doesn't exist on your version, the error names it: remove that line.
Keep the old admin permission until a full `terraform plan` and a test VM build work;
a "permission … denied" error names the privilege to add. Then remove the admin permission.
