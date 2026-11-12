export PROXMOX_VE_ENDPOINT=https://192.168.0.106:8006/
PVE_TOKEN_ID='terraform@pve!provider'
PVE_SECRET=$(cat ~/.pve_token)
export PROXMOX_VE_API_TOKEN="${PVE_TOKEN_ID}=${PVE_SECRET}"
unset PVE_SECRET
