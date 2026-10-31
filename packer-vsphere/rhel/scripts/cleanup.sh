#!/bin/bash
set -e
sudo dnf -y update
sudo dnf clean all
sudo truncate -s 0 /etc/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo rm -f /etc/NetworkManager/system-connections/*.nmconnection
