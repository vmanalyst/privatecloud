# a VM folder in vCenter for the prod VMs
resource "vsphere_folder" "prod" {
  path          = "Terraform-prod"
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# the Environment category already exists (dev created it) - look it up
data "vsphere_tag_category" "env" {
  name = "Environment"
}

resource "vsphere_tag" "prod" {
  name        = "prod"
  category_id = data.vsphere_tag_category.env.id
}