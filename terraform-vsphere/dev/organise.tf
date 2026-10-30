# a VM folder in vCenter for the dev VMs
resource "vsphere_folder" "dev" {
  path          = "Terraform-Dev"
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# a tag category, and one tag in it
resource "vsphere_tag_category" "env" {
  name             = "Environment"
  cardinality      = "SINGLE"
  associable_types = ["VirtualMachine"]
}

resource "vsphere_tag" "dev" {
  name        = "Dev"
  category_id = vsphere_tag_category.env.id
}