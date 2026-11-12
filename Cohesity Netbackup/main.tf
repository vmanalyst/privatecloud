locals {
  sizes = {
    small  = { cpus = 1, memory = 2048 }
    medium = { cpus = 2, memory = 4096 }
    large  = { cpus = 4, memory = 8192 }
    xlarge = { cpus = 8, memory = 16384 } # Hyper-V host with nested VMs
    bigmem = { cpus = 4, memory = 16384 } # NetBackup primary / media
    primary = { cpus = 8, memory = 32768 }
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each   = var.vms
  depends_on = [proxmox_virtual_environment_download_file.virtio_win] # ISO is ready before the VM exists

  name        = each.key
  vm_id       = each.value.vm_id # null = Proxmox picks the next free ID
  node_name   = local.node
  pool_id     = proxmox_virtual_environment_pool.dev.pool_id
  tags        = ["dev", "terraform"] # keep sorted, Proxmox sorts tags
  description = "Planned IP ${each.value.ip}/${local.networks[tostring(each.value.vlan)].prefix} gw ${local.networks[tostring(each.value.vlan)].gateway}\nManaged by Terraform"

  # UEFI + Secure Boot + TPM 2.0 (Server 2025 requirement)
  machine = "q35"
  bios    = "ovmf"

  efi_disk {
    datastore_id      = local.vm_storage
    type              = "4m"
    pre_enrolled_keys = true
  }

  tpm_state {
    datastore_id = local.vm_storage
    version      = "v2.0"
  }

  operating_system {
    type = local.images[each.value.os].ostype
  }

  cpu {
    cores = local.sizes[each.value.size].cpus
    type  = "host"
  }

  memory {
    dedicated = local.sizes[each.value.size].memory
    floating  = 0
  }

  scsi_hardware = "virtio-scsi-single"

  # OS disk (thin on LVM-thin / ZFS / Ceph; discard so Windows TRIM frees space)
  # os_disk_bus = "sata" lets Windows Setup see the disk with no VirtIO driver to load
  disk {
    datastore_id = local.vm_storage
    interface    = "${each.value.os_disk_bus}0"
    size         = each.value.os_disk_gb
    file_format  = "raw"
    iothread     = each.value.os_disk_bus == "scsi" # iothread is SCSI/VirtIO only
    discard      = "on"
    ssd          = true
  }

  # extra data disk, only for VMs that ask for one
  dynamic "disk" {
    for_each = each.value.data_disk_gb > 0 ? [1] : []
    content {
      datastore_id = local.vm_storage
      interface    = "scsi1"
      size         = each.value.data_disk_gb
      file_format  = "raw"
      iothread     = true
      discard      = "on"
      ssd          = true
    }
  }

  # Installer ISO. This provider version allows one cdrom block, so the
  # virtio-win ISO goes on ide0 by hand after apply:
  #   qm set <vmid> --ide0 local:iso/virtio-win.iso,media=cdrom
  cdrom {
    interface = "ide2"
    file_id   = local.images[each.value.os].iso
  }

  boot_order = ["${each.value.os_disk_bus}0", "ide2"]

  network_device {
    bridge  = local.networks[tostring(each.value.vlan)].bridge
    vlan_id = local.networks[tostring(each.value.vlan)].tag
    model   = "virtio"
  }

  # Turn on once virtio-win-guest-tools is installed in Windows
  agent {
    enabled = var.guest_agent
  }

  stop_on_destroy = true
  on_boot         = false

  lifecycle {
    prevent_destroy = false # set to true to protect these VMs, as on vSphere
    ignore_changes  = [cdrom, boot_order] # ISOs get ejected after install
  }
}

output "vm_ips" {
  value = { for name, vm in proxmox_virtual_environment_vm.vm : name => {
    vm_id   = vm.vm_id
    planned = var.vms[name].ip
    actual  = vm.ipv4_addresses # filled in once guest_agent = true
  } }
}
