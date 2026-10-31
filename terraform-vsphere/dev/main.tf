locals {
  sizes = {
    small  = { cpus = 1, memory = 2048 }
    medium = { cpus = 2, memory = 4096 }
    large  = { cpus = 4, memory = 8192 }
  }
}

resource "vsphere_virtual_machine" "vm" {
  for_each = var.vms

  name                 = each.key
  resource_pool_id     = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_cluster_id = data.vsphere_datastore_cluster.dsc.id
  folder     = each.value.folder
  depends_on = [vsphere_folder.dev]
  tags                 = [vsphere_tag.dev.id]

  num_cpus  = local.sizes[each.value.size].cpus
  memory    = local.sizes[each.value.size].memory
  cpu_hot_add_enabled    = false
  memory_hot_add_enabled = true
  guest_id  = data.vsphere_virtual_machine.template[each.value.os].guest_id
  firmware  = data.vsphere_virtual_machine.template[each.value.os].firmware
  scsi_type = data.vsphere_virtual_machine.template[each.value.os].scsi_type

  network_interface {
    network_id   = data.vsphere_network.net[tostring(each.value.vlan)].id
    adapter_type = data.vsphere_virtual_machine.template[each.value.os].network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = max(each.value.os_disk_gb, data.vsphere_virtual_machine.template[each.value.os].disks[0].size)
    thin_provisioned = true
  }

  dynamic "disk" {
    for_each = each.value.data_disk_gb > 0 ? [1] : []
    content {
      label            = "disk1"
      unit_number      = 1
      size             = each.value.data_disk_gb
      thin_provisioned = true
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template[each.value.os].id

    customize {
      dynamic "linux_options" {
        for_each = startswith(each.value.os, "win") ? [] : [1]
        content {
          host_name = each.key
          domain    = "lab.internal"
        }
      }

      dynamic "windows_options" {
        for_each = startswith(each.value.os, "win") ? [1] : []
        content {
          computer_name  = each.key
          admin_password = var.windows_admin_password
          workgroup      = "WORKGROUP"
        }
      }

      network_interface {
        ipv4_address = each.value.ip
        ipv4_netmask = local.networks[tostring(each.value.vlan)].prefix
      }

      ipv4_gateway    = local.networks[tostring(each.value.vlan)].gateway
      dns_server_list = ["172.16.11.5"]
      dns_suffix_list = ["lab.internal"]
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "vm_ips" {
  value = { for name, vm in vsphere_virtual_machine.vm : name => vm.default_ip_address }
}