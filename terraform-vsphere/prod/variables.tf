variable "vms" {
  type = map(object({
    ip           = string
    vlan         = optional(number, 1611)
    size         = optional(string, "small")
    os           = optional(string, "ubuntu")
    folder       = optional(string, "Terraform-Prod")
    data_disk_gb = optional(number, 0)
    os_disk_gb   = optional(number, 0)
  }))
}

variable "windows_admin_password" {
  type      = string
  sensitive = true
  default   = null
}
