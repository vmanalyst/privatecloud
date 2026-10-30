variable "vms" {
  type = map(object({
    ip           = string
    size         = optional(string, "small")
    os           = optional(string, "ubuntu")
    data_disk_gb = optional(number, 0)
  }))
}

variable "windows_admin_password" {
  type      = string
  sensitive = true
  default   = null
}