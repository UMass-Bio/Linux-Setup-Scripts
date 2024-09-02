#!/bin/sh

#Meant to be run on Ubuntu Pro Minimal

set -eu

output(){
    printf '\e[1;34m%-6s\e[m\n' "${@}"
}

unpriv(){
    sudo -u nobody "$@"
}

virtualization=$(systemd-detect-virt)

# Set system time
sudo timedatectl set-timezone America/New_York

# Compliance and updates
sudo systemctl mask debug-shell.service

# Setting umask to 077
umask 077
sudo sed -i 's/^UMASK.*/UMASK 077/g' /etc/login.defs
sudo sed -i 's/^HOME_MODE/#HOME_MODE/g' /etc/login.defs
sudo sed -i 's/^USERGROUPS_ENAB.*/USERGROUPS_ENAB no/g' /etc/login.defs

# Make home directory private
sudo chmod 700 /home/*

# Setup NTS
sudo systemctl disable --now systemd-timesyncd
sudo systemctl mask systemd-timesyncd
sudo apt install -y chrony
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf | sudo tee /etc/chrony/chrony.conf > /dev/null
sudo chmod 644 /etc/chrony/chrony.conf
sudo systemctl restart chronyd

# Harden SSH
unpriv curl -s https://raw.githubusercontent.com/Umass-Bio/Linux-Setup-Scripts/main/etc/ssh/sshd_config.d/10-custom.conf | sudo tee /etc/ssh/sshd_config.d/10-custom.conf > /dev/null
sudo chmod 644 /etc/ssh/sshd_config.d/10-custom.conf
unpriv curl -s https://raw.githubusercontent.com/UMass-Bio/Linux-Setup-Scripts/main/etc/ssh/ssh_config.d/10-custom.conf | sudo tee /etc/ssh/ssh_config.d/10-custom.conf > /dev/null
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf
sudo mkdir -p /etc/systemd/system/ssh.service.d/
sudo chmod 755 /etc/systemd/system/ssh.service.d/
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/local.conf | sudo tee /etc/systemd/system/ssh.service.d/override.conf > /dev/null
sudo chmod 644 /etc/systemd/system/ssh.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ssh

# Security kernel settings
unpriv curl -s https://raw.githubusercontent.com/secureblue/secureblue/live/files/system/etc/modprobe.d/blacklist.conf | sudo tee /etc/modprobe.d/server-blacklist.conf > /dev/null
sudo chmod 644 /etc/modprobe.d/server-blacklist.conf
unpriv curl -s https://raw.githubusercontent.com/UMass-Bio/Linux-Setup-Scripts/main/etc/sysctl.d/99-server.conf | sudo tee /etc/sysctl.d/99-server.conf > /dev/null
sudo chmod 644 /etc/sysctl.d/99-server.conf
sudo sysctl -p

# Rebuild initramfs
sudo update-initramfs -u

# Disable coredump
unpriv curl -s https://raw.githubusercontent.com/UMass-Bio/Linux-Setup-Scripts/main/etc/security/limits.d/30-disable-coredump.conf | sudo tee /etc/security/limits.d/30-disable-coredump.conf > /dev/null
sudo chmod 644 /etc/security/limits.d/30-disable-coredump.conf
sudo mkdir -p /etc/systemd/coredump.conf.d
sudo chmod 755 /etc/systemd/coredump.conf.d
unpriv curl -s https://raw.githubusercontent.com/UMass-Bio/Linux-Setup-Scripts/main/etc/systemd/coredump.conf.d/disable.conf | sudo tee /etc/systemd/coredump.conf.d/disable.conf > /dev/null
sudo chmod 644 /etc/systemd/coredump.conf.d/disable.conf

# Update GRUB config
if [ ! -d /boot/efi/EFI/ZBM ]; then
  # shellcheck disable=SC2016
  sudo sed -i 's/splash/splash mitigations=auto,nosmt spectre_v2=on spectre_bhi=on spec_store_bypass_disable=on tsx=off kvm.nx_huge_pages=force nosmt=force l1d_flush=on spec_rstack_overflow=safe-ret gather_data_sampling=force reg_file_data_sampling=on random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=force_isolation efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none ia32_emulation=0 page_alloc.shuffle=1 randomize_kstack_offset=on debugfs=off console=tty0 console=ttyS0,115200/g' /etc/default/grub
  sudo update-grub
fi

# Disable telemetry
sudo systemctl disable --now apport.service
sudo systemctl mask apport.service

## Avoid phased updates
sudo apt install -y curl
unpriv curl -s https://raw.githubusercontent.com/UMass-Bio/Linux-Setup-Scripts/main/etc/apt/apt.conf.d/99sane-upgrades | sudo tee /etc/apt/apt.conf.d/99sane-upgrades > /dev/null
sudo chmod 644 /etc/apt/apt.conf.d/99sane-upgrades

sudo apt update -y
sudo apt full-upgrade -y
sudo apt autoremove -y

## Install basic sysadmin tools
sudo apt install -y nano iputils-ping

# Install appropriate virtualization drivers
if [ "$virtualization" = 'kvm' ]; then
    sudo apt install -y qemu-guest-agent
fi

# Enable fstrim.timer
sudo systemctl enable --now fstrim.timer

### Differentiating bare metal and virtual installs

# Setup tuned
sudo apt install -y tuned
sudo systemctl enable --now tuned

if [ "$virtualization" = 'none' ]; then
    sudo tuned-adm profile latency-performance
else
    sudo tuned-adm profile virtual-guest
fi

# Setup fwupd
if [ "$virtualization" = 'none' ]; then
    sudo apt install -y fwupd
    echo 'UriSchemes=file;https' | sudo tee -a /etc/fwupd/fwupd.conf
    sudo systemctl restart fwupd
    mkdir -p /etc/systemd/system/fwupd-refresh.service.d
    unpriv curl -s https://raw.githubusercontent.com/UMass-Bio/Linux-Setup-Scripts/main/etc/systemd/system/fwupd-refresh.service.d/override.conf | sudo tee /etc/systemd/system/fwupd-refresh.service.d/override.conf > /dev/null
    sudo chmod 644 /etc/systemd/system/fwupd-refresh.service.d/override.conf
    sudo systemctl daemon-reload
    sudo systemctl enable --now fwupd-refresh.timer
else
    sudo apt purge -y fwupd
fi

# Setup unbound

sudo apt install -y unbound dns-root-data

echo 'server:
  trust-anchor-signaling: yes
  root-key-sentinel: yes
  tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt

  hide-identity: yes
  hide-trustanchor: yes
  hide-version: yes
  deny-any: yes
  harden-algo-downgrade: yes
  harden-large-queries: yes
  harden-referral-path: yes
  ignore-cd-flag: yes
  max-udp-size: 3072
  module-config: "validator iterator"
  qname-minimisation-strict: yes
  unwanted-reply-threshold: 10000000
  use-caps-for-id: yes

  outgoing-port-permit: 1024-65535

  prefetch: yes
  prefetch-key: yes

#  ip-transparent: yes
#  interface: 127.0.0.1
#  interface: ::1
#  interface: 242.242.0.1
#  access-control: 242.242.0.0/16 allow

forward-zone:
  name: "."
  forward-tls-upstream: yes
  forward-addr: 1.1.1.2@853#security.cloudflare-dns.com
  forward-addr: 1.0.0.2@853#security.cloudflare-dns.com
  forward-addr: 2606:4700:4700::1112@853#security.cloudflare-dns.com
  forward-addr: 2606:4700:4700::1002@853#security.cloudflare-dns.com' | sudo tee /etc/unbound/unbound.conf.d/custom.conf

sudo chmod 644 /etc/unbound/unbound.conf.d/custom.conf

sudo mkdir -p /etc/systemd/system/unbound.service.d
unpriv curl -s https://raw.githubusercontent.com/UMass-Bio/Linux-Setup-Scripts/main/etc/systemd/system/unbound.service.d/override-chroot.conf | sudo tee /etc/systemd/system/unbound.service.d/override.conf > /dev/null
sudo chmod 644 /etc/systemd/system/unbound.service.d/override.conf

sudo systemctl daemon-reload
sudo systemctl restart unbound
sudo systemctl disable systemd-resolved

# Setup networking

# UFW Snap is strictly confined, unlike its .deb counterpart
sudo apt purge -y ufw
sudo apt install -y snapd
sudo snap install ufw
echo 'y' | sudo ufw enable
sudo ufw allow SSH

sudo reboot
