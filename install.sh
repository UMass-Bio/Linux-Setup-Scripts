#!/bin/bash

#Please note that this is how I PERSONALLY setup my computer - I do some stuff such as not using anything to download GNOME extensions from extensions.gnome.org and installing the extensions as a package instead
#Customize it to your liking
#Run this script as your user, NOT root

#Written by yours truly, Tomster

#Variables
USER=$(whoami)
PARTITIONID=$(sudo cat /etc/crypttab | awk '{print $1}')
PARTITIONUUID=$(sudo blkid -s UUID -o value /dev/mapper/${PARTITIONID}) 

#Moving to the home directory
#Note that I always use /home/${USER} because gnome-terminal is wacky and sometimes doesn't load the environment variables in correctly (Right click somewhere in nautilus, click on open in terminal, then hit create new tab and you will see.)
cd /home/${USER} || exit

#Setting umask to 077
umask 077
sudo sed -i 's/umask 002/umask 077/g' /etc/bashrc
sudo sed -i 's/umask 022/umask 077/g' /etc/bashrc

#Disable ptrace
sudo cp /usr/lib/sysctl.d/10-default-yama-scope.conf /etc/sysctl.d/
sudo sed -i 's/kernel.yama.ptrace_scope = 0/kernel.yama.ptrace_scope = 3/g' /etc/sysctl.d/10-default-yama-scope.conf
sudo sysctl --load=/etc/sysctl.d/10-default-yama-scope.conf

#Setup Firewalld
sudo firewall-cmd --permanent --remove-port=1025-65535/udp
sudo firewall-cmd --permanent --remove-port=1025-65535/tcp
sudo firewall-cmd --permanent --remove-service=mdns
sudo firewall-cmd --permanent --remove-service=ssh
sudo firewall-cmd --permanent --remove-service=samba-client
sudo firewall-cmd --reload

#Speed up DNF
sudo echo 'fastestmirror=1' | sudo tee -a /etc/dnf/dnf.conf
sudo echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf
sudo echo 'deltarpm=true' | sudo tee -a /etc/dnf/dnf.conf

#Update packages and firmware
sudo dnf upgrade -y
sudo fwupdmgr get-devices
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates
sudo fwupdmgr update

#Remove unneeded packages
sudo dnf -y remove *cron* abrt f33-backgrounds-gnome nm-connection-editor mozilla-filesystem chrome-gnome-shell quota* nmap-ncat virtualbox-guest-additions spice-vdagent nfs-utils teamd tcpdump sgpio ImageMagick* adcli libreoffice* lvm2 qemu-guest-agent hyperv* gnome-classic* baobab *kkc* *zhuyin* *pinyin* *evince* *yelp* ModemManager fedora-bookmarks fedora-chromium-config fedora-workstation-backgrounds gnome-tour gnome-themes-extra gnome-shell-extension-background-logo gnome-screenshot gnome-remote-desktop gnome-font-viewer gnome-calculator gnome-backgrounds NetworkManager-pptp-gnome NetworkManager-ssh-gnome NetworkManager-openconnect-gnome NetworkManager-openvpn-gnome NetworkManager-vpnc-gnome podman*  *libvirt* open-vm* *speech* sos totem gnome-characters firefox eog openssh-server dmidecode xorg-x11-drv-vmware xorg-x11-drv-amdgpu yajl words ibus-hangui vino openh264 twolame-libs realmd rsync net-snmp-libs net-tools traceroute mtr geolite2* gnome-boxes gnome-disk-utility gedit gnome-calendar cheese gnome-contacts rythmbox gnome-screenshot gnome-maps gnome-weather gnome-logs ibus-typing-booster *m17n* gnome-clocks gnome-color-manager mlocate cups cups-filesystem cyrus-sasl-plain cyrus-sasl-gssapi sssd* gnome-user* dos2unix kpartx rng-tools ppp* ntfs* xfs* tracker* thermald *perl* gnome-shell-extension-apps-menu gnome-shell-extension-horizontal-workspaces gnome-shell-extension-launch-new-instance gnome-shell-extension-places-menu gnome-shell-extension-window-list

#Disable openh264 repo
sudo dnf config-manager --set-disabled fedora-cisco-openh264 -y

#Install packages that I use
sudo dnf -y install neofetch git-core flat-remix-gtk3-theme libappindicator-gtk3 gnome-shell-extension-appindicator gnome-shell-extension-system-monitor-applet gnome-shell-extension-dash-to-dock gnome-shell-extension-freon gnome-shell-extension-openweather gnome-shell-extension-user-theme gnome-tweak-tool f29-backgrounds-gnome gnome-system-monitor nautilus gvfs-mtp gvfs-goa git-core firejail setroubleshoot gnome-software PackageKit PackageKit-command-not-found fedora-workstation-repositories openssl

#Install Yubico Stuff
sudo dnf -y install yubikey-manager pam-u2f pamu2fcfg
mkdir -p /home/${USER}/.config/Yubico

#Install IVPN
sudo dnf config-manager --add-repo https://repo.ivpn.net/stable/fedora/generic/ivpn.repo -y
sudo dnf -y install ivpn-ui 

#Install openSnitch
sudo dnf install -y https://github.com/evilsocket/opensnitch/releases/download/v1.3.6/opensnitch-1.3.6-1.x86_64.rpm
sudo dnf install -y https://github.com/evilsocket/opensnitch/releases/download/v1.3.6/opensnitch-ui-1.3.6-1.f29.noarch.rpm

#Setting up Flatpak
flatpak remote-add --user flathub https://flathub.org/repo/flathub.flapakrepo
flatpak remove --unused

#Install default applications
flatpak install flathub com.github.tchx84.Flatseal org.videolan.VLC org.gnome.eog com.vscodium.codium org.gnome.Calendar org.gnome.Contacts -y 

#Enable auto TRIM
sudo systemctl enable fstrim.timer

#Enable Firejail
sudo firecfg

#Download and set GNOME shell theme
git clone https://github.com/i-mint/midnight.git
mkdir /home/${USER}/.themes
ln -s /home/${USER}/midnight/Midnight-* /home/${USER}/.themes/
gsettings set org.gnome.shell.extensions.user-theme name "Midnight-Blue"

#Download and set icon theme
git clone https://github.com/NicoHood/arc-icon-theme.git
mkdir /home/${USER}/.icons 
ln -s /home/${USER}/arc-icon-theme/Arc /home/${USER}/.icons/
git clone https://github.com/zayronxio/Mojave-CT.git
ln -s /home/${USER}/Mojave-CT /home/${USER}/.icons/
sed -i 's/Inherits=Moka,Adwaita,gnome,hicolor/Inherits=Mojave-CT,Moka,Adwaita,gnome,hicolor/g' /home/${USER}/arc-icon-theme/Arc/index.theme
find /home/${USER}/arc-icon-theme -name '*[Tt]rash*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Nn]autilus*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Gg]nome.[Ss]ettings*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Gg]nome.[Tt]weak*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Gg]nome.[Ss]oftware*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Gg]nome.[Bb]oxes*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Ss]team*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Tt]hunderbird*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Mm]inecraft*' -exec rm {} \;
gsettings set org.gnome.desktop.interface icon-theme "Arc"

#Set GTK theme
gsettings set org.gnome.desktop.interface gtk-theme "Flat-Remix-GTK-Blue-Dark"
flatpak upgrade -y

#Set Fedora 29 Animated Wallpaper
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/f29/default/f29.xml'

#Enable Titlebar buttons
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'

#Quick Fixes for Flatpak Steam if I install it on the system
ln -s /home/${USER}/.var/app/com.valvesoftware.Steam/.local/share/Steam /home/${USER}/.local/share/Steam

sudo bash -c 'cat > /etc/sysctl.d/99-steam.conf' <<-'EOF'
dev.i915.perf_stream_paranoid=0
EOF

sudo sysctl --load=/etc/sysctl.d/99-steam.conf

sudo bash -c 'cat > /etc/pulse/daemon.conf' <<-'EOF'
# $ sudo nano /etc/pulse/daemon.conf

# Start as daemon 
daemonize = yes
allow-module-loading = yes

# Realtime optimization
high-priority = yes
realtime-scheduling = yes
realtime-priority = 9

# Scales the device-volume with the volume of the "loudest" application
flat-volumes = no

# Script file management
load-default-script-file = yes
default-script-file = /etc/pulse/default.pa

# Sample rate
resample-method = speex-float-9
default-sample-format = s24-32le
default-sample-rate = 192000
alternate-sample-rate = 176000
exit-idle-time = -1

# Optimized fragements for steam
default-fragments = 5
default-fragment-size-msec = 2

# Volume
deferred-volume-safety-margin-usec = 1
EOF

#Quick Fix for Freon https://github.com/UshakovVasilii/gnome-shell-extension-freon/issues/163
sudo sed -i 's#`${nvme}#`/usr/bin/sudo ${nvme}#g' /usr/share/gnome-shell/extensions/freon@UshakovVasilii_Github.yahoo.com/nvmecliUtil.js
echo ''"${USER}"'   ALL = NOPASSWD: /usr/sbin/nvme list -o json, /usr/sbin/nvme smart-log /dev/nvme* -o json' | sudo EDITOR='tee -a' visudo >/dev/null 2>&1

#Enable GNOME shell extensions
gsettings set org.gnome.shell disable-user-extensions false

#Enable tap to click
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

#Install and sign NVIDIA proprietary drivers
sudo dnf copr enable egeretto/kmodtool-secureboot -y
sudo dnf copr enable egeretto/akmods-secureboot -y
sudo dnf install akmods kmodtool -y
sudo /usr/sbin/kmodgenca -a
sudo dnf config-manager --set-enabled rpmfusion-nonfree-nvidia-driver -y
sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda -y

#Reenable Wayland... They are working to support it, and if you aren't gaming you shouldn't stay on x11 anyways
sudo sed -i 's^DRIVER=="nvidia", RUN+="/usr/libexec/gdm-disable-wayland"^#DRIVER=="nvidia", RUN+="/usr/libexec/gdm-disable-wayland"^g' /usr/lib/udev/rules.d/61-gdm.rules

#Setup BTRFS layout and Timeshift
sudo mkdir /btrfs_pool
sudo mount -o subvolid=5 /dev/mapper/${PARTITIONID} /btrfs_pool
sudo mv /btrfs_pool/root /btrfs_pool/@
sudo mv /btrfs_pool/home /btrfs_pool/@home
sudo btrfs subvolume list /btrfs_pool
sudo sed -i 's/subvol=root/subvol=@,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async/' /etc/fstab
sudo sed -i 's/subvol=home/subvol=@home,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async/' /etc/fstab
sudo echo "UUID=${PARTITIONUUID} /btrfs_pool             btrfs   subvolid=5,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async,x-systemd.device-timeout=0   0 0" | sudo tee -a /etc/fstab
sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
sudo dnf -y install timeshift

#Randomize MAC address
sudo bash -c 'cat > /etc/NetworkManager/conf.d/00-macrandomize.conf' <<-'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
connection.stable-id=${CONNECTION}/${BOOT}
EOF

sudo systemctl restart NetworkManager

#Last step, import key to MOK
sudo mokutil --import /etc/pki/akmods/certs/public_key.der