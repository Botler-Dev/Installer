#!/bin/bash

# TODO: Make comment on purpouse of this variable
export linuxPMI_revision="3"
export _LINUXPMI="/home/bolter/linuxPMI.sh"

# Checks to see if this script was executed with root privilege
if ((EUID != 0)); then 
    echo "Please run this script as root or with root privilege" >&2
    echo -e "\nExiting..."
    exit 1 
fi

echo "Downloading 'linux-master-installer.sh'..."
#wget -N https://raw.githubusercontent.com/Botler-Dev/Installer/master/linux-master-installer.sh || {
wget -N https://raw.githubusercontent.com/Botler-Dev/Installer/dev/linux-master-installer.sh || {
    echo "Failed to download 'linux-master-installer.sh'..." >&2
    echo -e "\nExiting..."
    exit 1
}
chmod +x linux-master-installer.sh && ./linux-master-installer.sh
