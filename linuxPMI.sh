#!/bin/bash

# Keeps track of changes to linuxPMI.sh in combination with the master installer
export linuxPMI_revision="3"

# Checks to see if this script was executed with root privilege
if ((EUID != 0)); then 
    echo "Please run this script as root or with root privilege" >&2
    echo -e "\nExiting..."
    exit 1 
fi

echo "Downloading 'linux-master-installer.sh'..."
#wget -N https://raw.githubusercontent.com/Botler-Dev/Installer/release/latest/linux-master-installer.sh || { # Latest release branch
#wget -N https://raw.githubusercontent.com/Botler-Dev/Installer/master/linux-master-installer.sh || { # Working dev branch
wget -N https://raw.githubusercontent.com/Botler-Dev/Installer/dev/linux-master-installer.sh || { # Dev branch
    echo "Failed to download 'linux-master-installer.sh'..." >&2
    echo -e "\nExiting..."
    exit 1
}
chmod +x linux-master-installer.sh && ./linux-master-installer.sh
