variable "vms" {
  type = map(object({
    ip           = string
    vlan         = optional(number, 1611)
    size         = optional(string, "large")
    #os           = optional(string, "win2025")
    os           = optional(string, "win2022")
    os_disk_gb   = optional(number, 80)
    os_disk_bus  = optional(string, "sata") # "sata" = no driver at install; "scsi" = faster, needs vioscsi
    data_disk_gb = optional(number, 0)
    vm_id        = optional(number)
  }))
}

variable "guest_agent" {
  type    = bool
  default = false
}
