#!/bin/bash

################################################################################
#
# linuxPMI acts as the intermediary between the server Botler is being hosted
# on and the linux master installer. To prevent any conflict with updates to
# the installer, this script has as little code as deemed necessary. In
# addition, linuxPMI is the only script that will remain on the system.
#
# Note: The only thing the end user should ever change abou this file, is
# 'botler_version' and 'installer_branch'. Though, please read the
# documentation before messing with anything in this script.
#
################################################################################
#
    export linuxPMI_revision="4"    # Keeps track of changes to linuxPMI.sh
    export botler_version="latest"  # Determins which version of Botler is used
    export installer_branch="dev"   # Determins which installer branch is used

    # Checks to see if this script was executed with root privilege
    if ((EUID != 0)); then 
        echo "Please run this script as root or with root privilege" >&2
        echo -e "\nExiting..."
        exit 1 
    fi

    echo "Downloading 'installer-prep.sh'..."
    wget -N https://raw.githubusercontent.com/Botler-Dev/Installer/$installer_branch/installer-prep.sh || {
        echo "Failed to download 'installer-prep.sh'..." >&2
        echo -e "\nExiting..."
        exit 1
    }
    chmod +x installer-prep.sh && ./installer-prep.sh
