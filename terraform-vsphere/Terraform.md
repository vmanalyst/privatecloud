# Terraform for vSphere: dev and prod

Builds and manages vSphere VMs from a simple list. Each VM picks a size,
OS, VLAN and folder from small tables, so nobody types specs by hand.

## Layout

```text
terraform-vsphere/
├── env.sh     vCenter login (prompts for the password, never stores it)
├── dev/       dev VMs   (own state)
└── prod/      prod VMs  (own state, protected from deletes)
```

Each folder: `providers.tf`, `data.tf`, `variables.tf`, `main.tf`, `organise.tf`, `terraform.tfvars`

| File | What it does |
| --- | --- |
| `providers.tf` | use the vSphere plugin |
| `data.tf` | finds datacenter, cluster, datastore, templates and networks; holds the **OS** and **VLAN** tables |
| `variables.tf` | what a VM line can contain (ip, vlan, size, os, folder, data disk) |
| `main.tf` | the VM recipe, plus the **size** table |
| `organise.tf` | vCenter folder and tag for the environment |
| `terraform.tfvars` | **the list of VMs** - the file you edit day to day |

## Before you start

- A template in vCenter with open-vm-tools, your user and SSH key,
  and machine-id / SSH host keys / netplan cleared
- A vCenter service account (here: `svc-automation@vsphere.local`)
- Names in `data.tf` must match vCenter exactly

## Run it

```bash
cd terraform-vsphere/dev        # or prod - always run INSIDE the folder
source ../env.sh
terraform init                  # first time only
terraform plan -out=tfplan      # preview - read it
terraform apply tfplan          # do exactly what the plan showed
```

## Day to day: edit terraform.tfvars only

```hcl
vms = {
  "dev-ubuntu-01" = { ip = "172.16.11.151", size = "small" }
  "bank-db-01"    = { ip = "172.16.11.172", size = "large", folder = "Banking/DB", data_disk_gb = 100 }
  "dev-web-01"    = { ip = "172.16.19.151", vlan = 1619 }
}
```

| Task | Change |
| --- | --- |
| Add a VM | add a line |
| Resize | change `size` (small / medium / large) |
| Extra disk | `data_disk_gb = 50` |
| Other VLAN | `vlan = 1619` (the IP must match the VLAN) |
| Other folder | `folder = "Banking/Apps"` (the folder must exist) |
| Other OS | `os = "centos"` (template must exist and be in the table) |
| Decommission | delete the line |

- New size: one line in the sizes table (`main.tf`)
- New OS or VLAN: one line in the templates or networks table (`data.tf`)
- A field that "does nothing"? Check it's declared in `variables.tf` - undeclared fields are silently ignored.

## Plan symbols

| Symbol | Meaning |
| --- | --- |
| `+` | create |
| `~` | change in place |
| `-` | destroy |
| `-/+` | replace (destroy and rebuild) - stop and check |

## Prod protection

`prod/main.tf` has:

```hcl
lifecycle {
  prevent_destroy = true
}
```

To decommission a prod VM: comment out the lifecycle block, remove the VM line,
plan (check it shows only that one destroy), apply, then put the protection back.
Everyday changes (CPU, memory, disks, folders, tags) still work with it on.

## Never commit

`terraform.tfstate*`, `.terraform/`, `tfplan`, passwords.
