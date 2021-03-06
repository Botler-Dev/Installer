#!/bin/bash

################################################################################
#
# This master installer looks at the operating system, architecture, bit type,
# etc., to determine whether or not the system is supported by Botler. Once the
# system is deemed as supported, the appropriate sub-master installer will be
# chosen, downloaded, then executed.
#
# Note: All variables not defined in this script, are exported from
# 'linuxPMI.sh'.
#
################################################################################
#
# Exported and/or globally used [ variables ]
#
################################################################################
#
    yellow=$'\033[1;33m'
    green=$'\033[0;32m'
    cyan=$'\033[0;36m'
    red=$'\033[1;31m'
    nc=$'\033[0m'
    clrln=$'\r\033[K'
    current_linuxPMI_revision="4"

#
################################################################################
#
# Exported only [ variables ]
#
################################################################################
#
    # The '--no-hostname' flag for journalctl only works with systemd 230 and
    # later
    if (($(journalctl --version | grep -oP "[0-9]+" | head -1) >= 230)); then
        export no_hostname="--no-hostname"
    fi

    export master_installer="/home/botler/linux-master-installer.sh"
    export master_installer_pid=$$

#
################################################################################
#
# Error [ traps ]
#
################################################################################
#
    clean_exit() {
        local installer_files=("sub-master-installer.sh" "nodejs-installer.sh"
            "postgres-installer.sh" "botconfig-setup.sh" "ormconfig-setup.sh"
            "postgres-open-close.sh" "download-update.sh" "linux-master-installer.sh")

        if [[ $3 = "true" ]]; then echo "Cleaning up..."; else echo -e "\nCleaning up..."; fi
        for file in "${installer_files[@]}"; do
            if [[ -f $file ]]; then rm "$file"; fi
        done

        echo "${2}..."
        exit "$1"
    }

    # TODO: Figure out a way to solve the bug where this is printed x number of
    # times, where x is the number of times the download options was used in
    # the current section +1
    trap "echo -e \"\n\nScript forcefully stopped\"
        clean_exit \"1\" \"Exiting\" \"true\"" \
        SIGINT SIGTSTP SIGTERM

#
################################################################################
#
# Makes sure that linuxPMI.sh is up to date
#
################################################################################
#
    if [[ $linuxPMI_revision != $current_linuxPMI_revision ]]; then
        echo "${yellow}'linuxPMI.sh' is not up to date${nc}"
        echo "Downloading latest 'linuxPMI.sh'..."
        wget -qN https://raw.githubusercontent.com/Botler-Dev/Installer/$installer_branch/linuxPMI.sh || {
            echo "${red}Failed to download latest 'linuxPMI.sh'...${nc}" >&2
            clean_exit "1" "Exiting" "true"
        }
        chmod +x linuxPMI.sh
        echo "${cyan}Re-execute 'linuxPMI.sh'${nc}"
        clean_exit "0" "Exiting" "true"
        # TODO: Figure out a way to get exec to work 
    fi

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
        clean_exit "1" "Exiting" "true"
    fi

    # Changes the working directory to that of where the executed script is
    # located
    cd "$(dirname "$0")" || {
        echo "${red}Failed to change working directories" >&2
        echo "${cyan}Change your working directory to the same directory of" \
            "the executed script${nc}"
        clean_exit "1" "Exiting" "true"
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
        #echo "Downloading 'sub-master-installer.sh'..."
        while true; do
            wget -qN https://raw.githubusercontent.com/Botler-Dev/Installer/$installer_branch/sub-master-installer.sh || {
                failed_download "sub-master-installer.sh"
            }
            break
        done

        chmod +x sub-master-installer.sh && ./sub-master-installer.sh || {
            echo "${red}Failed to execute 'debian-ubuntu-installer.sh'${nc}" >&2
            clean_exit "1" "Exiting" "true"
        }
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
    clear -x

    detect_sys_info
    export distro sver ver arch bits codename
    export yellow green cyan red nc clrln
    export -f clean_exit

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
                    execute_sub_master_installer "apt"
                else
                    supported="false"
                fi
                ;;
            18.04)
                # B.1.
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "apt"
                else
                    supported="false"
                fi
                ;;
            20.04)
                # B.1.
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "apt"
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
                    execute_sub_master_installer "apt"
                else
                    supported="false"
                fi
                ;;
            10)
                # B.1.
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "apt"
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
                    execute_sub_master_installer "yum"
                else
                    supported="false"
                fi
                ;;
            8)
                # B.1.
                if [[ $bits = 64 ]]; then
                    execute_sub_master_installer "dnf"
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
        clean_exit "1" "Exiting" "true"
    fi
