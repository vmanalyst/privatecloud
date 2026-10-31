#cloud-config
autoinstall:
  version: 1
  locale: en_GB.UTF-8
  keyboard:
    layout: gb
  network:
    version: 2
    ethernets:
      nic0:
        match:
          name: "en*"
        addresses: [${build_ip}/24]
        routes:
          - to: default
            via: 172.16.11.1
        nameservers:
          addresses: [172.16.11.5]
  storage:
    layout:
      name: direct
  ssh:
    install-server: true
    allow-pw: false
  packages:
    - open-vm-tools
    - dnsutils
    - net-tools
    - wget
  early-commands:
    - systemctl stop ssh
  user-data:
    hostname: ${hostname}
    timezone: Europe/London
    disable_root: true
    users:
      - name: awx
        groups: [sudo]
        sudo: "ALL=(ALL) NOPASSWD:ALL"
        shell: /bin/bash
        lock_passwd: true
        ssh_authorized_keys:
          - ${ssh_key}
