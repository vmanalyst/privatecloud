text
url --url=${baseos_url}
repo --name=AppStream --baseurl=${appstream_url}
lang en_GB.UTF-8
keyboard gb
timezone Europe/London --utc
network --bootproto=static --ip=${build_ip} --netmask=255.255.255.0 --gateway=172.16.11.1 --nameserver=172.16.11.5 --activate --hostname=${hostname}
rootpw --lock
user --name=awx --groups=wheel --lock
sshkey --username=awx "${ssh_key}"
selinux --enforcing
firewall --enabled --ssh
zerombr
clearpart --all --initlabel
autopart --type=plain --nohome
bootloader --timeout=1
firstboot --disabled
services --enabled=vmtoolsd
reboot --eject

%packages
@^minimal-environment
open-vm-tools
perl
vim-enhanced
bind-utils
net-tools
tar
wget
%end

%post
echo 'awx ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/awx
chmod 440 /etc/sudoers.d/awx
%end
