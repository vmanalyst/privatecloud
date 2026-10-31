vms = {
  "prod-ubuntu-01" = { ip = "172.16.19.151", size = "small",vlan = 1619, os = "ubuntu" }
  "prod-ubuntu-02" = { ip = "172.16.19.152", size = "medium", vlan = 1619, os = "ubuntu" }
  "prod-ubuntu-03" = { ip = "172.16.19.153", size = "small",  vlan = 1619, os = "ubuntu", data_disk_gb = 70, os_disk_gb = 20 }
  "prod-centos-01" = { ip = "172.16.19.151", size = "small", vlan = 1619, os = "ubuntu" }

  "bank-app-01" = { ip = "172.16.19.171", size = "medium", folder = "Banking/Apps" }
  "bank-db-01"  = { ip = "172.16.19.172", size = "large",  folder = "Banking/DB", data_disk_gb = 12 }
  "mkt-web-01"  = { ip = "172.16.19.173", folder = "Marketing" }
  "prod-test-01" = { ip = "172.16.19.174" }                      
}