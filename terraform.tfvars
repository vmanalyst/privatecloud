vms = {
  # Hyper-V host (OS disk currently on SATA after the install workaround)
  "ws25-hv01" = { ip = "172.16.11.160", vm_id = 2500, size = "xlarge", os_disk_gb = 80, data_disk_gb = 150 }

  # NetBackup 11 lab
  "nbu-primary"  = { ip = "172.16.11.170", vm_id = 2510, size = "primary", os_disk_gb = 100, data_disk_gb = 100 } # D: = catalog
  "nbu-media01"  = { ip = "172.16.11.171", vm_id = 2511, size = "bigmem", os_disk_gb = 80, data_disk_gb = 500 }  # E: = MSDP pool
  "nbu-client01" = { ip = "172.16.11.172", vm_id = 2512, size = "medium", os_disk_gb = 60, data_disk_gb = 20 }   # test data to back up
  "nbu-ad01"     = { ip = "172.16.11.6", vm_id = 2513, size = "medium", os_disk_gb = 60}   # AD Server
}

guest_agent = false
