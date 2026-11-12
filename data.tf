# Names must match Proxmox exactly.
#   node        - the PVE node name (Datacenter > <node> in the UI)
#   vm_storage  - where OS/data disks, EFI vars and TPM state go
#   iso_storage - storage with content type "ISO image"
#   images      - one entry per OS; there are no templates yet, so Windows installs from ISO
#   networks    - same VLAN table as vSphere; on Proxmox a VLAN is a tag on a VLAN-aware bridge

locals {
  node        = "pve"
  vm_storage  = "samsung-12TB"
  iso_storage = "local"

  images = {
    win2025 = {
      iso    = "local:iso/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso" # pvesm list local --content iso  /var/lib/vz/template/iso/.
      ostype = "win11"                                     # PVE type for Win11 / Server 2022 / 2025
    }

     win2022 = {
      iso    = "local:iso/SERVER_EVAL_x64FRE_en-us.iso" # pvesm list local --content iso  /var/lib/vz/template/iso/.
      ostype = "win11"                                     # PVE type for Win11 / Server 2022 / 2025
    }
    # ubuntu = { template_id = 9000, ostype = "l26" }      # once a cloud-init template exists
  }

  networks = {
    "1611" = { bridge = "vmbr1", tag = 1611, gateway = "172.16.11.1", prefix = 24 }
    "1619" = { bridge = "vmbr1", tag = 1619, gateway = "172.16.19.1", prefix = 24 }
  }
}

# virtio-win drivers: Windows can't see a VirtIO SCSI disk or NIC without them.
# Proxmox downloads it straight into iso_storage.
resource "proxmox_virtual_environment_download_file" "virtio_win" {
  node_name           = local.node
  datastore_id        = local.iso_storage
  content_type        = "iso"
  url                 = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
  file_name           = "virtio-win.iso"
  overwrite           = false
  overwrite_unmanaged = true
  upload_timeout      = 1800
}
