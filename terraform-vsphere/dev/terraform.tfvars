vms = {
  "dev-ubuntu-03" = { ip = "172.16.11.153", size = "small",  vlan = 1611, os = "ubuntu", data_disk_gb = 10, os_disk_gb = 20 }
  "bank-app-01" = { ip = "172.16.11.171", size = "medium", folder = "Banking/Apps" }
  "bank-db-01"  = { ip = "172.16.11.172", size = "small",  folder = "Banking/DB", data_disk_gb = 8 }
  "mkt-web-01"  = { ip = "172.16.11.173", folder = "Marketing" }
  "dev-test-01" = { ip = "172.16.11.174" }     
  # created with new ubuntu26 template in content library on Nov 1, 2026
  "teller-app-01"  = { ip = "172.16.11.179", size = "small", vlan = 1611, os = "ubuntu26", folder = "Banking/DB", data_disk_gb = 5 }   
  # created with Ubuntu 24 templates in content library on Nov 1, 2026
  "new-app-01" = { ip = "172.16.11.180", size = "small", vlan = 1611, os = "rocky", folder = "Marketing" } 
  #created with Ubuntu 24 templates in content library on Dec 1, 2026
  #"new-app-02" = { ip = "172.16.11.181", size = "small", vlan = 1611, os = "ubuntu22_2611", folder = "Marketing" }  
    # created with Ubuntu 26 templates in content library on Dec 1, 2026
 # "new-app-03" = { ip = "172.16.11.182", size = "small", vlan = 1611, os = "ubuntu22_2611", folder = "Marketing" }  
}
