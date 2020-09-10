#!/bin/bash

################################################################################
#
# Runs Botler in the background, as a service on the system.
# If Botler is already running in this mode, he'll be restarted instead
#
# Note: All variables (excluding $timer and $start_time) are exported from
# 'linux-master-installer.sh', and 'debian-ubuntu-installer.sh' or
# 'centos-rhel-installer.sh'.
#
################################################################################
#
    timer=20

    clear
    printf "We will now run Botler in the background. "
    read -p "Press [Enter] to begin."

    # Saves the current time and date, which will be used with journalctl
    start_time=$(date +"%F %H:%M:%S")

#
################################################################################
#
# Disables 'botler.service'
#
################################################################################
#
    # If 'botler.service' is enabled
    if [[ $botler_service_startup = 0 ]]; then
        echo "Disabling 'botler.service'..."
        systemctl disable botler.service || {
            echo "${red}Failed to disable 'botler.service'" >&2
            echo "${cyan}This service must be disabled in order to use this" \
                "run mode${nc}"
            read -p "Press [Enter] to return to the installer menu"
            exit 1
        }
    fi

#
################################################################################
#
# Starting or restarting 'botler.service'
#
################################################################################
#
    if [[ $botler_service_status = "active" ]]; then
        echo "Restarting 'botler.service'..."
        systemctl restart botler.service || {
            echo "${red}Failed to restart 'botler.service'${nc}" >&2
            read -p "Press [Enter] to return to the installer menu"
            exit 1
        }
        echo "Waiting 20 seconds for 'botler.service' to restart..."
    else
        echo "Starting 'botler.service'..."
        systemctl start botler.service || {
            echo "${red}Failed to start 'botler.service'${nc}" >&2
            read -p "Press [Enter] to return to the installer menu"
            exit 1
        }
        echo "Waiting 20 seconds for 'botler.service' to start..."
    fi

#
################################################################################
#
# Waits then displays the startup logs of 'botler.service'
#
################################################################################
#
    # Waits in order to give 'botler.service' enough time to (re)start
    while ((timer > 0)); do
        echo -en "${clrln}${timer} seconds left"
        sleep 1
        ((timer-=1))
    done

    # Note: $no_hostname is purposefully unquoted. Do not quote those variables.
    echo -e "\n\n-------- botler.service startup logs ---------" \
        "\n$(journalctl -u botler -b $no_hostname -S "$start_time")" \
        "\n--------- End of botler.service startup logs --------\n"

    echo -e "${cyan}Please check the logs above to make sure that there aren't any" \
        "errors, and if there are, to resolve whatever issue is causing them\n"

    echo "${green}Botler is now running in the background${nc}"
    read -p "Press [Enter] to return to the installer menu"
