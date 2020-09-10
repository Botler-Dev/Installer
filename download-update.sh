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
            apt -y install "$1" || apt -y install $2 || {
                echo "${red}Failed to install $1" >&2
                echo "${cyan}${1} must be installed to continue${nc}"
                clean_exit "1" 
            }
        fi
    }

    # Cleans up any loose ends/left over files
    clean_up() {
        echo "Cleaning up files and directories..."
        if [[ -d tmp ]]; then rm -r tmp; fi

        if [[ ! -d src || ! -f package-lock.json || ! -f package.json ]]; then
            echo "Restoring from 'Old_Botler/${old_botler}'"
            cp -rf Old_Botler/"$old_botler"/* . && cp -rf Old_Botler/"$old_botler"/.* . || {
                echo "${red}Failed to restore from 'Old_Botler'${nc}" >&2
            }
        fi

        echo "Changing ownership of the file(s) in '/home/botler'..."
        chown botler:botler -R "$home"
    }

#
################################################################################
#
# [ Main ]
#
################################################################################
#
    clear
    printf "We will now download/update Botler. "
    read -p "Press [Enter] to begin."
    
    old_botler=$(date)
    repo="https://github.com/Botler-Dev/Botler/"


    ############################################################################
    # Error trapping
    ############################################################################
    # TODO: Test more and maybe modify
    trap "echo -e \"\n\nScript forcefully stopped\" && clean_up; echo \
        \"Exiting...\" && exit" SIGINT SIGTERM SIGTSTP


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
    required_software "git"
    required_software "gpg2" "gnupg2"


    ############################################################################
    # Creating backups of current code in '/home/botler' then downloads/
    # updates Botler
    ############################################################################
    if [[ ! -d Old_Botler ]]; then
        echo "Creating 'Old_Botler/'..."
        mkdir Old_Botler
    fi

    echo "Creating 'Old_Botler/${old_botler}'..."
    mkdir Old_Botler/"$old_botler"
    # Makes sure that any changes to 'out/botconfig.json' by the user, are
    # made to 'src/botconfig.json' so when the code is compiled, the
    # changes will be passed on to the new 'out/botconfig.json'
    if [[ -f out/botconfig.json ]]; then
        cat out/botconfig.json > src/botconfig.json
    fi

    echo "Backing up code to 'Old_Botler/${old_botler}'..."
    for dir in "${files[@]}"; do
        if [[ -d $dir || -f $dir ]]; then
            cp -rf "$dir" Old_Botler/"$old_botler" || {
                echo "${red}Failed to backup the code to 'Old_Botler/${old_botler}'${nc}" >&2
            }
        fi
    done
    
    if [[ -d .git ]]; then
        git checkout -- \*
        git pull || {
            echo "${red}Failed to update Botler${nc}" >&2
            echo "${cyan}Forcefully resetting changes may resolve" \
                "the issue that is occuring: 'git fetch --all && git reset" \
                "--hard origin/release'${nc}" 
            clean_up
            clean_exit "1" 
        }
    else
        echo "Downloading Botler..."
        #git clone --single-branch -b release "$repo" tmp || {
        git clone --single-branch -b master "$repo" tmp || {
            echo "${red}Failed to download Botler${nc}" >&2
            clean_up
            clean_exit "1" 
        }
        mv -f tmp/* . && mv -f tmp/.git* . || {
            echo "${red}Failed to move updated code from 'tmp/' to ." >&2
            echo "${cyan}Manually move all the files from tmp to .${nc}"
            clean_exit "1" 
        }
        rm -rf tmp
    fi
    
    # Checks if it's possible to compile code
    if (! hash tsc || ! hash node) &>/dev/null || [[ ! -f src/botconfig.json ]]; then
        echo "Skipping typescript compilation..."
    else
        echo "Compiling code..."
        tsc || {
            echo "${red}Failed to compile code${nc}" >&2
            clean_exit "1" 
        }
        echo -e "\n${cyan}If there are any errors, resolve whatever issue" \
            "is causing them, then attempt to compile the code again\n${nc}"
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
    #clear
