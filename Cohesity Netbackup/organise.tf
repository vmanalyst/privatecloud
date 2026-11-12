# A Proxmox pool for dev VMs (the vCenter folder equivalent).
# The "dev" tag is set on each VM in main.tf; Proxmox tags need no category.

resource "proxmox_virtual_environment_pool" "dev" {
  pool_id = "Terraform-Dev"
  comment = "Managed by Terraform"
}
