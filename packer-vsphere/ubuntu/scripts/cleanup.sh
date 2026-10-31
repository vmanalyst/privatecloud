#!/bin/bash
set -e
sudo apt-get -o DPkg::Lock::Timeout=300 update
sudo apt-get -o DPkg::Lock::Timeout=300 -y upgrade
sudo apt-get -y autoremove
sudo apt-get clean

sudo tee /etc/systemd/system/regen-ssh-keys.service >/dev/null <<'UNIT'
[Unit]
Description=Regenerate SSH host keys
Before=ssh.service
ConditionPathExists=!/etc/ssh/ssh_host_ed25519_key
[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl enable regen-ssh-keys.service

sudo cloud-init clean --logs
sudo touch /etc/cloud/cloud-init.disabled
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo rm -f /etc/netplan/*.yaml
