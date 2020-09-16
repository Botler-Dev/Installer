#!/bin/bash

################################################################################
#
# Downloads and updates Botler  
#
# Note: All variables not defined in this script, are exported from
# 'linux-master-installer.sh' and 'sub-master-installer.sh'.
#
################################################################################
#
# [ Functions ]
#
################################################################################
#
    # Installs software/applications used by the installers
    required_software() {
        if ! hash "$1" &>/dev/null; then
            echo "${yellow}${1} is not installed${nc}"
            echo "Installing ${1}..."
            apt -y install "$1" || {
                echo "${red}Failed to install $1" >&2
                echo "${cyan}${1} must be installed to continue${nc}"
                echo -e "\nPress [Enter] to return to the installer menu"
                clean_exit "1" "Returning to the installer menu"
            }
        fi
    }

    # Cleans up any loose ends/left over files
    clean_up() {
        local installer_files=("sub-master-installer.sh" "nodejs-installer.sh"
            "postgres-installer.sh" "botconfig-setup.sh" "ormconfig-setup.sh"
            "postgres-open-close.sh" "download-update.sh" "linux-master-installer.sh")

        echo "Cleaning up files and directories..."
        if [[ -d tmp ]]; then rm -rf tmp; fi
        if [[ -f $botler_version ]]; then rm "$botler_version"; fi
        if [[ -d Botler ]]; then rm -rf Botler; fi
        for file in "${installer_files[@]}"; do
            if [[ -f $file ]]; then rm "$file"; fi
        done

        if [[ -d Botler.bak ]]; then
            echo "Restoring from 'Botler.bak'"
            mv -f Botler.bak Botler || {
                echo "${red}Failed to restore from 'Botler.old'" >&2
                echo "${cyan} Manually rename 'Botler.old' to 'Botler'${nc}"
            }

            echo "Changing ownership of the file(s) in '/home/botler'..."
            chown botler:botler -R "$home"
        fi

        if [[ $1 = "true" ]]; then
            echo "Killing parent processes..."
            kill -9 "$sub_master_installer_pid" "$master_installer_pid"
            echo "Exiting..."
            exit 1
        fi
    }

#
################################################################################
#
# [ Main ]
#
################################################################################
#
    clear -x
    printf "We will now download/update Botler. "
    read -p "Press [Enter] to begin."
    

    ############################################################################
    # Error trapping
    ############################################################################
    # TODO: Figure out how to silently kill a process
    trap "echo -e \"\n\nScript forcefully stopped\"
        clean_up
        echo \"Killing parent processes...\"
        kill -9 \"$sub_master_installer_pid\" \"$master_installer_pid\"
        echo \"Exiting...\"
        exit 1" \
        SIGINT SIGTSTP SIGTERM


    ############################################################################
    # Prepping
    ############################################################################
    if [[ $botler_service_status = "active" ]]; then
        # B.1. $botler_service_active = true when 'botler.service' is
        # active, and is used to indicate to the user that the service was
        # stopped and that they will need to start it
        botler_service_active="true"
        echo "Stopping 'botler.service'..."
        systemctl stop botler.service || {
            echo "${red}Failed to stop 'botler.service'" >&2
            echo "${cyan}You will need to restart 'botler.service' to" \
                "apply any updates to Botler${nc}"
        }
    fi


    ############################################################################
    # Checking for required software/applications
    ############################################################################
    required_software "curl"
    required_software "wget"


    ############################################################################
    # Creating backups of current code in '/home/botler' then downloads/
    # updates Botler
    ############################################################################
    if [[ $botler_version = "latest" ]]; then
        #botler_version=$(curl -s https://api.github.com/repos/Botler-Dev/Botler/releases/latest \
        #   | grep -oP '"tag_name": "\K(.*)(?=")')
        botler_version=$(curl -s https://api.github.com/repos/CodeBullet-Community/BulletBot/releases/latest \
           | grep -oP '"tag_name": "\K(.*)(?=")')
    fi
    #latest_release="https://github.com/Botler-Dev/Botler/tarball/${botler_version}"
    latest_release="https://github.com/CodeBullet-Community/BulletBot/tarball/${botler_version}"

    # Makes sure that any changes to 'Botler/out/botconfig.json' by the user, are
    # made to 'Botler/src/botconfig.json' so when the code is compiled, the
    # changes will be passed on to the new 'Botler/out/botconfig.json'
    if [[ -f Botler/out/botconfig.json ]]; then
        cat Botler/out/botconfig.json > Botler/src/botconfig.json
    fi

    # Saves botconfig.json (if it exists) to a temporary directory
    if [[ -f Botler/src/botconfig.json ]]; then
        if [[ ! -d tmp ]]; then
            mkdir tmp || {
                echo "Failed to create 'tmp/'" >&2
                echo "${cyan}Please create it manually before continuing${nc}"
                echo -e "\nPress [Enter] to return to the installer menu"
                clean_exit "1" "Returning to the installer menu"
            }
        fi

        cp Botler/src/botconfig.json tmp/ || {
            echo "${red}Failed to copy 'botconfig.json' to 'tmp/'" >&2
            echo "${cyan}Please copy it manually before continuing${nc}"
            echo -e "\nPress [Enter] to return to the installer menu"
            clean_exit "1" "Returning to the installer menu"
        }
    fi

    if [[ -d Botler ]]; then
        echo "Backing up Botler as Botler.bak..."
        mv -f Botler Botler.bak || {
            echo "${red}Failed to back up Botler${nc}" >&2
            echo -e "\nPress [Enter] to return to the installer menu"
            clean_exit "1" "Returning to the installer menu"
        }
    fi

    echo "Downloading latest release..."
    wget -N "$latest_release" || {
        echo "${red}Failed to download the latest release" >&2
        echo "${cyan}Either resolve the issue (recommended) or download" \
            "the latest release from github${nc}"
        clean_up "true"
    }
    
    echo "Untarring '$tag'..."    
    #tar -zxf "$tag" && mv Botler-Dev-Botler-* Botler || {
    tar -zxf "$tag" && mv CodeBullet-Community-BulletBot-* Botler || {
        echo "${red}Failed to unzip '$tag'" >&2
        clean_up "true"
    }
    echo "Removing '$tag'..."
    rm "$tag" 2>/dev/null || echo "${red}Failed to remove" \
        "'$tag'${nc}" >&2
    
    if [[ -f tmp/botconfig.json ]]; then
        cp -f tmp/botconfig.json Botler/out/ && rm -rf tmp/ || {
            echo "${red}Failed to move 'botconfig.json' to 'Botler/out/'" >&2
            echo "${yellow}Before starting BulletBot, you will have to" \
                "manually move 'botconfig.json' from 'tmp/' to 'Botler/out/'${nc}"
        }
    fi

    # Checks if it's possible to compile code
    if (! hash tsc || ! hash node) &>/dev/null || [[ ! -f Botler/src/botconfig.json ]]; then
        echo "Skipping typescript compilation..."
    else
        echo "Compiling code..."
        tsc || {
            echo "${red}Failed to compile code${nc}" >&2
            clean_up "true"
        }
        echo -e "\n${cyan}If there are any errors, resolve whatever issue" \
            "is causing them, then attempt to compile the code again\n${nc}"
    fi

    if [[ -d Botler.old && -d Botler.bak || ! -d Botler.old && -d Botler.bak ]]; then
    # TODO: Add error handling???
        rm -rf Botler.old
        mv -f Botler.bak Botler.old
    fi

    if [[ -f $botler_service ]]; then
        echo "Updating 'botler.service'..."
        create_or_update="update"
    else
        echo "Creating 'botler.service'..."
        create_or_update="create"
    fi
    
    echo -e "$botler_service_content" > "$botler_service" || {
        echo "${red}Failed to $create_or_update 'botler.service'${nc}" >&2
        b_s_update="Failed"
    }


    ############################################################################
    # Cleaning up and presenting results...
    ############################################################################
    echo "Changing ownership of the file(s) added to '/home/botler/'..."
    chown botler:botler -R "$home"
    echo -e "\n${green}Finished downloading/updating Botler${nc}"
    
    if [[ $b_s_update ]] ;then
        echo "${yellow}WARNING: Failed to $create_or_update 'botler.service'${nc}"
    fi

    # B.1.
    if [[ $botler_service_active ]]; then
        echo "${cyan}NOTE: 'botler.service' was stopped to update" \
            "Botler and has to be started using the run modes in the" \
            "installer menu${nc}"
    fi

    read -p "Press [Enter] to apply any existing changes to the installers"
