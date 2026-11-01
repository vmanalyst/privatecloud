data "vsphere_datacenter" "dc" {
  name = "DC1"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "Cluster01"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore_cluster" "dsc" {
  name          = "Lab-DatastoreCluster"
  datacenter_id = data.vsphere_datacenter.dc.id
}

locals {
  templates = {
    ubuntu = "tpl-ubuntu-2204"
    ubuntu26 = "tpl-ubuntu-2604"
    rocky  = "tpl-rocky9"
    # centos  = "tpl-centos-9"
    # win2022 = "tpl-win2022"
    # alma9 = "tpl-alma9"
  }

  networks = {
    "1611" = { portgroup = "VM-1611-mgmt",  gateway = "172.16.11.1", prefix = 24 }
    "1619" = { portgroup = "VM-1619-vmnet", gateway = "172.16.19.1", prefix = 24 }
  }
}

data "vsphere_virtual_machine" "template" {
  for_each      = toset([for vm in var.vms : vm.os])
  name          = local.templates[each.key]
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "net" {
  for_each      = toset([for vm in var.vms : tostring(vm.vlan)])
  name          = local.networks[each.key].portgroup
  datacenter_id = data.vsphere_datacenter.dc.id
}
