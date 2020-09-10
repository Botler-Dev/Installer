#!/bin/bash

################################################################################
#
# This master installer looks at the operating system, architecture, bit type,
# etc., to determine whether or not the system is supported by Botler. Once the
# system is deemed as supported, the appropriate sub-master installer will be
# chosen, downloaded, then executed.
#
################################################################################
#
# [ Variables ] used outside of this script and/or globally
#
################################################################################
#
    yellow=$'\033[1;33m'
    green=$'\033[0;32m'
    cyan=$'\033[0;36m'
    red=$'\033[1;31m'
    nc=$'\033[0m'
    clrln=$'\r\033[K'

#
################################################################################
#
# [ Variables ] exported and used only outside of the master installer
#
################################################################################
#
    # The '--no-hostname' flag for journalctl only works with systemd 230 and
    # later
    if (($(journalctl --version | grep -oP "[0-9]+" | head -1) >= 230)); then
        export no_hostname="--no-hostname"
    fi

    export master_installer="/home/botler/linux-master-installer.sh"

#
################################################################################
#
# Checks for root privilege and working directory
#
################################################################################
#
    # Checks to see if this script was executed with root privilege
    if ((EUID != 0)); then 
        echo "${red}Please run this script as root or with root privilege${nc}" >&2
        echo -e "\nExiting..."
        exit 1
    fi

    # Changes the working directory to that of where the executed script is
    # located
    cd "$(dirname "$0")" || {
        echo "${red}Failed to change working directories" >&2
        echo "${cyan}Change your working directory to the same directory of" \
            "the executed script${nc}"
        echo -e "\nExiting..."
        exit 1
    }

#
################################################################################
#
# [ Functions ]
#
################################################################################
#
    # Identify the operating system, version number, architecture, bit type (32
    # or 64), etc.
    detect_sys_info() {
        arch=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
        
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            distro="$ID"
            # Version: x.x.x...
            ver="$VERSION_ID"
            # Version: x (short handed version)
            sver=${ver//.*/}
            pname="$PRETTY_NAME"
            codename="$VERSION_CODENAME"
        else
            distro=$(uname -s)
            ver=$(uname -r)
        fi

        # Identifying bit type
        case $(uname -m) in
            x86_64)
                bits="64"
                ;;
            i*86)
                bits="32"
                ;;
            armv*)
                bits="32"
                ;;
            *)
                bits="?"
                ;;
        esac

        # Identifying architecture type
        case $(uname -m) in
            x86_64)
                arch="x64"  # or AMD64 or Intel64 or whatever
                ;;
            i*86)
                arch="x86"  # or IA32 or Intel32 or whatever
                ;;
            *)
                arch="?"
                ;;
        esac
    }

    execute_sub_master_installer(){
        supported="true"
        export pkg_mng=$1
        echo "Downloading 'sub-master-installer.sh'..."
        while true; do
            #wget -N https://raw.githubusercontent.com/Botler-Dev/Installer/master/$2/sub-master-installer.sh || {
            wget -N https://raw.githubusercontent.com/Botler-Dev/Installer/dev/$2/sub-master-installer.sh || {
                echo "${red}Failed to download 'sub-master-installer.sh'..." >&2
                if ! hash wget &>/dev/null; then
                    echo "${yellow}wget is not installed${nc}"
                    echo "Installing wget..."
                    $1 install -y wget || {
                        echo "${red}Failed to install wget${nc}"
                        echo -e "\nExiting..."
                        exit 1
                    }
                    echo "Attempting to download 'sub-master-installer.sh'..."
                else
                    echo "${red}Failed to download 'sub-master-installer.sh'${nc}" >&2
                    echo -e "\nExiting..."
                    exit 1
                fi
            }
            break
        done

        chmod +x sub-master-installer.sh && ./sub-master-installer.sh || {
            echo "${red}Failed to execute 'debian-ubuntu-installer.sh'${nc}" >&2
            echo -e "\nExiting..."
            exit 1
        }
        rm sub-master-installer.sh
    }

#
################################################################################
#
# [ Main ]
#
# Executes the sub-master installer that corresponds to the system's Linux
# Distribution (i.e. Ubuntu, Debian, CentOS, RHEL)
#
################################################################################
#
    detect_sys_info
    export distro sver ver arch bits codename
    export yellow green cyan red nc clrln

    echo "SYSTEM INFO"
    echo "Bit Type: $bits"
    echo "Architecture: $arch"
    echo -n "Linux Distro: "
    if [[ -n $pname ]]; then echo "$pname"; else echo "$distro"; fi
    echo "Linux Distro Version: $ver"
    echo ""

    if [[ $distro = "ubuntu" ]]; then
        case "$ver" in
            16.04)
                # B.1. Forcing 64 bit architecture
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "apt" "Debian-Ubuntu"
                else
                    supported="false"
                fi
                ;;
            18.04)
                # B.1.
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "apt" "Debian-Ubuntu"
                else
                    supported="false"
                fi
                ;;
            20.04)
                # B.1.
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "apt" "Debian-Ubuntu"
                else
                    supported="false"
                fi
                ;;
            *)
                supported="false"
                ;;
        esac
    elif [[ $distro = "debian" ]]; then
        case "$sver" in
            9)
                # B.1.
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "apt" "Debian-Ubuntu"
                else
                    supported="false"
                fi
                ;;
            10)
                # B.1.
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "apt" "Debian-Ubuntu"
                else
                    supported="false"
                fi
                ;;
            *)
                supported="false"
                ;;
        esac
    elif [[ $distro = "rhel" || $distro = "centos" ]]; then
        case "$sver" in
            7)
                # B.1.
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "yum" "CentOS-RHEL"
                else
                    supported="false"
                fi
                ;;
            8)
                # B.1.
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "dnf" "CentOS-RHEL"
                else
                    supported="false"
                fi
                ;;
            *)
                supported="false"
                ;;
        esac
    else
        supported="false"
    fi
        
    if [[ $supported = "false" ]]; then
        echo "${red}Your operating system/Linux Distribution is not supported" \
            "by the installation, setup, and/or use of Botler${nc}" >&2
        echo -e "\nExiting..."
        exit 1
    fi
