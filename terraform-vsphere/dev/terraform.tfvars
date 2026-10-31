vms = {
  "dev-ubuntu-03" = { ip = "172.16.11.153", size = "small",  vlan = 1611, os = "ubuntu", data_disk_gb = 70, os_disk_gb = 20 }
  "dev-centos-01" = { ip = "172.16.19.151", size = "small", vlan = 1619, os = "ubuntu" }
  "rocky-01" = { ip = "172.16.19.157", size = "small", vlan = 1619, os = "rocky" }
  
  "bank-app-01" = { ip = "172.16.11.171", size = "medium", folder = "Banking/Apps" }
  "bank-db-01"  = { ip = "172.16.11.172", size = "large",  folder = "Banking/DB", data_disk_gb = 12 }
  "mkt-web-01"  = { ip = "172.16.11.173", folder = "Marketing" }
  "dev-test-01" = { ip = "172.16.11.174" }     
  # created with new ubuntu template
  "teller-app-01"  = { ip = "172.16.11.179", size = "small",  folder = "Banking/DB", data_disk_gb = 5 }
  # created with new alma9 template
  "my-vdi-01"   = { ip = "172.16.11.180", size = "medium", folder = "Banking/Apps", data_disk_gb = 10 }                 
}

