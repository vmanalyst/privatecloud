terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.83.0"
    }
  }
}

# Endpoint and API token come from env.sh (PROXMOX_VE_ENDPOINT / PROXMOX_VE_API_TOKEN)
provider "proxmox" {
  insecure = true
}
