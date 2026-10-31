export VSPHERE_SERVER=vcenter.lab.internal
export VSPHERE_USER=svc-automation@vsphere.local
read -s -p "Password: " VSPHERE_PASSWORD; echo; export VSPHERE_PASSWORD
