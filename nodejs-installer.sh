#!/bin/bash

################################################################################
#
# Installs Node.js (version 14.x) and the required packages and
# dependencies for Botler to run. Node.js is installed using the instructions
# described here:
# https://github.com/nodesource/distributions/blob/master/README.md
#
# Note: All variables not defined in this script, are exported from
# 'linuxPMI.sh', 'linux-master-installer.sh', and 'sub-master-installer.sh'.
#
################################################################################
#
# [ Functions ]
#
################################################################################
#
    install_nodejs() {
        echo "Downloading the Node.js repo installer..."
        if [[ $distro = "rhel" || $distro = "centos" ]]; then
            curl -sL https://rpm.nodesource.com/setup_14.x | bash - || {
                echo "${red}Failed to download the Node.js installer${nc}" >&2
                read -p "Press [Enter] to return to the installer menu"
                exit 1
            }
        else
            curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash - || {
                echo "${red}Failed to download the Node.js installer${nc}" >&2
                read -p "Press [Enter] to return to the installer menu"
                exit 1
            }
        fi

        echo "Installing nodejs..."
        $pkg_mng -y install nodejs || {
            echo "${red}Failed to install nodejs${nc}" >&2
            read -p "Press [Enter] to return to the installer menu"
            exit 1
        }
    }

    install_node_module_pkgs() {
        while true; do
            if hash npm &>/dev/null; then
                echo "Installing required packages and dependencies..."
                # Installs production packages only
                # TODO: 'npm install --only=prod || {' OR 'npm ci || {' ???
                npm install --prefix Botler/ --only=prod || {
                    echo "${red}Failed to install required packages and" \
                        "dependencies${nc}" >&2
                    read -p "Press [Enter] to return to the installer menu"
                    exit 1
                }
                npm install -g typescript || {
                    echo "${red}Failed to install typescript globally" >&2
                    echo "${cyan}Typescript is required to compile the code to" \
                        "JS${nc}"
                    read -p "Press [Enter] to return to the installer menu"
                    exit 1
                }
                npm fund || {
                    echo "${red}Failed to fund npm packages${nc}" >&2
                }
                break
            else
                echo "${yellow}npm is not installed${nc}"
                
                # Npm might not exist due to Node.js not being installed
                if (! hash node || ! hash nodejs) &>/dev/null; then
                    echo "${yellow}nodejs is not installed${nc}"
                    install_nodejs
                fi
                
                if ! hash npm &>/dev/null; then
                    echo "${red}npm is not installed" >&2
                    # Sometimes npm isn't installed for some reason, and it is
                    # necessary to reinstall Node.js
                    echo -e "${cyan}Try reinstalling nodejs, then try again" \
                        "\nTo reinstall nodejs: sudo $pkg_mng reinstall" \
                        "nodejs${nc}"
                    read -p "Press [Enter] to return to the installer menu"
                    exit 1
                fi
            fi
        done
    }

#
################################################################################
#
# [ Main ] code
#
################################################################################
#

    if ((option == 3)); then
        printf "We will now download and install nodejs and any required packages. "
        read -p "Press [Enter] to begin."
        install_nodejs
        install_node_module_pkgs
        echo "Changing ownership of the file(s) added to '/home/botler'..."
        chown botler:botler -R /home/botler
        echo -e "\n${green}Finished downloading and installing nodejs and any" \
            "required packages${nc}"
    else
        if ((option == 4)); then
            printf "We will now install the required packages and dependencies. " 
            read -p "Press [Enter] to begin."
        fi
        install_node_module_pkgs
        echo "Changing ownership of the file(s) added to '/home/botler'..."
        chown botler:botler -R /home/botler
        echo -e "\n${green}Finished installing required packages and" \
            "dependencies${nc}"
    fi

    read -p "Press [Enter] to return to the installer menu"

