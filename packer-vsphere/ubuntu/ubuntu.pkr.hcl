packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.4.0"
    }
  }
}

# login: from env.sh
variable "vcenter"  { default = env("VSPHERE_SERVER") }
variable "user"     { default = env("VSPHERE_USER") }
variable "password" {
  default   = env("VSPHERE_PASSWORD")
  sensitive = true
}

# where: from ../vsphere.pkrvars.hcl
variable "datacenter" {}
variable "cluster"    {}
variable "datastore"  {}
variable "folder"     {}
variable "network"    {}

# version: from ubuntu2204.pkrvars.hcl ...
variable "vm_name"       {}
variable "guest_os_type" {}
variable "iso_path"      {}
variable "build_ip"      {}

source "vsphere-iso" "ubuntu" {
  vcenter_server      = var.vcenter
  username            = var.user
  password            = var.password
  insecure_connection = true
  datacenter          = var.datacenter
  cluster             = var.cluster
  datastore           = var.datastore
  folder              = var.folder

  vm_name              = var.vm_name
  guest_os_type        = var.guest_os_type
  firmware             = "efi"
  CPUs                 = 2
  RAM                  = 2048
  disk_controller_type = ["pvscsi"]
  storage {
    disk_size             = 20480
    disk_thin_provisioned = true
  }
  network_adapters {
    network      = var.network
    network_card = "vmxnet3"
  }

  iso_paths = [var.iso_path]
  cd_label  = "cidata"
  cd_content = {
    "meta-data" = ""
    "user-data" = templatefile("${path.root}/data/user-data.pkrtpl.hcl", {
      hostname = var.vm_name
      build_ip = var.build_ip
      ssh_key  = trimspace(file(pathexpand("~/.ssh/automation_ed25519.pub")))
    })
  }
  boot_order = "disk,cdrom"
  boot_wait  = "10s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]

  ssh_host             = var.build_ip
  ssh_username         = "awx"
  ssh_private_key_file = "~/.ssh/automation_ed25519"
  ssh_timeout          = "60m"
  shutdown_command     = "sudo shutdown -P now"

  convert_to_template = true
}

build {
  sources = ["source.vsphere-iso.ubuntu"]

  provisioner "shell" {
    script = "scripts/cleanup.sh"
  }
}
