#!/bin/bash

################################################################################
#
# The sub-master installer
#
# Note: All variables not defined in this script, are exported from
# 'linux-master-installer.sh'.
#
################################################################################
#
# Global [ variables ]
#
################################################################################
#
    home="/home/botler"
    botler_service="/lib/systemd/system/botler.service"
    # Contains all of the files/directories that are associated with Botler
    # (only files/directories located in the Botler root directory)
    # TODO: Current files in root dir may change
    files=("linuxPMI.sh" "linux-master-installer.sh" "package-lock.json" \
        "package.json" "tsconfig.json" "src/" "media/" "README.md" "out/" \
        "mkdocs.yml" "mkdocs-requirements.txt" ".gitignore/" "docs/" \
        ".github" "CODE_OF_CONDUCT.md" "CONTRIBUTING.md" "LICENSE")
    botler_service_content="[Unit] \
        \nDescription=Starts Botler after a crash or system reboot \
        \nAfter=network.target postgresql-12.service  \
        \n  \
        \n[Service]  \
        \nUser=botler  \
        \nWorkingDirectory=$home \
        \nExecStart=/usr/bin/node out/main.js \
        \n#ExecStart=/usr/bin/node $home/out/main.js  \
        \nRestart=always  \
        \nRestartSec=3  \
        \nStandardOutput=syslog  \
        \nStandardError=syslog  \
        \nSyslogIdentifier=botler  \
        \n  \
        \n[Install]  \
        \nWantedBy=multi-user.target"

#
################################################################################
#
# [ Functions ]
#
################################################################################
#
    # Changes ownership of new files so that they are owned by the botler
    # system user
    change_ownership() {
        echo "Changing ownership of the file(s) added to '/home/botler'..."
        chown botler:botler -R "$home"
        cd "$home" || {
            echo "${red}Failed to change working directory to" \
                "'/home/botler'" >&2
            echo "${cyan}Change your working directory to '/home/botler'${nc}"
            clean_exit "1" 
        }
    }

    # Moves Botler's code to '/home/botler' if it's executed outside of it's
    # home directory
    move_to_home() {
        echo "Moving files/directories associated with Botler to '$home'..."
        for dir in "${files[@]}"; do
            # C.1. If two separate directories with the same name exist in
            # $home and the current dir...
            if [[ -d "${home}/${dir}" && -d $dir ]]; then
                # D.1. Removes the directory in $home because an error would
                # occur when moving $dir to $home
                rm -rf "${home:?}/${dir:?}"
            fi
            # C.1. and D.1. are done because a directory can't overwrite
            # another directory that contains files
            mv -f "$dir" "$home" 2>/dev/null
        done
    }

#
################################################################################
#
# [ Main ] code
#
################################################################################
#
    echo -e "Welcome to the Botler installer\n"
    while true; do
        # TODO: Numerics for $botler_service_status like $botler_service_startup???
        botler_service_status=$(systemctl is-active botler.service)
        botler_service_startup=$(systemctl is-enabled --quiet botler.service \
            2>/dev/null; echo $?)
        database_user_exist=$(sudo -u postgres -H sh -c "psql postgres -tAc \
            \"SELECT 1 FROM pg_roles WHERE rolname='Botler'\"" 2>/dev/null)
        database_exist=$(sudo -u postgres -H sh -c "psql postgres -tAc \
            \"SELECT 1 FROM pg_database WHERE datname='Botler_DB'\"" 2>/dev/null)
        pgsql_auth_type=$(grep -P "^host.*all.*all.*(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2])).*ident$" /var/lib/pgsql/12/data/pg_hba.conf 2>/dev/null) # CentOS/RHEL


        ########################################################################
        # Makes sure that the system user 'botler' and the home directory
        # '/home/botler' already exists, and that your working directory is
        # '/home/botler'.
        # 
        # TL;DR: Makes sure that all necessary (important) services, files,
        # directories, and users exist and are in their proper locations.
        ########################################################################
        # Creates a system user named 'botler', if it does not already exist,
        # along with a home directory for it
        if ! id -u botler &>/dev/null; then
            echo "${yellow}System user 'botler' does not exist${nc}" >&2
            echo "Creating system user 'botler'..."
            if [[ $distro = "rhel" || $distro = "centos" ]]; then
                useradd --system -Um -k /dev/null botler || {
                    echo "${red}Failed to create 'botler'" >&2
                    echo "${cyan}System user 'botler' must exist in order to" \
                        "continue${nc}"
                    clean_exit "1"
                }
                echo "Changing permissions of '/home/botler'..."
                # Permissions for the home directory need to be changed, else an
                # error will be produced when trying to install the 'node_module'
                chmod 755 "$home"
            else
                adduser --system --group botler || {
                    echo "${red}Failed to create 'botler'" >&2
                    echo "${cyan}System user 'botler' must exist in order to" \
                        "continue${nc}"
                    clean_exit "1" 
                }
            fi

            move_to_home
            change_ownership
        # Creates botler's home directory if it does not exist
        elif [[ ! -d $home ]]; then
            echo "${yellow}botler's home directory does not exist${nc}" >&2
            echo "Creating '$home'..."
            mkdir "$home"

            move_to_home
            change_ownership
        fi

        if [[ $PWD != "/home/botler" ]]; then
            move_to_home
            change_ownership
        fi   
        
        # E.1. Creates 'botler.service', if it does not exist
        if [[ ! -f $botler_service ]]; then
            echo "Creating 'botler.service'..."
            echo -e "$botler_service_content" > "$botler_service" || {
                echo "${red}Failed to create 'botler.service'" >&2
                echo "${cyan}This service must exist for Botler to work${nc}"
                clean_exit "1" 
            }
            # Reloads systemd daemons to account for the added service
            systemctl daemon-reload
        fi


        ########################################################################
        # User options for installing perquisites, downloading Botler, and
        # starting Botler in different run modes
        ########################################################################
        # Checks to see if it is necessary to download Botler
        if [[ ! -d src && ! -d out ]]; then
            echo "${cyan}Botler is not downloaded. To continue," \
                "please download Botler via option 1.${nc}"

            echo "1. Download Botler"
            echo "2. Stop and exit script"
            read option
            case "$option" in
                1)
                    export home
                    export files
                    export botler_service
                    export botler_service_content
                    #wget -qN https://raw.githubusercontent.com/Botler-Dev/Installer/master/download-update.sh
                    wget -qN https://raw.githubusercontent.com/Botler-Dev/Installer/tarball/download-update.sh
                    chmod +x download-update.sh && ./download-update.sh
                    exec "$master_installer"
                    ;;
                2)
                    clean_exit "0"
                    ;;
                *)
                    clear
                    echo "${red}Invalid input: '$option' is not a valid" \
                        "option${nc}" >&2
                    continue
                    ;;
            esac
        # If any of the prerequisites are not installed or set up, the user will
        # be required to install them using the options below
        elif (! hash psql || ! hash node || ! hash npm || [[ ! $database_exist ||
                ! $database_user_exist || ! -f out/botconfig.json || ! -f \
                ormconfig.json || ! -d node_modules ]] ||
                ! $pgsql_auth_type) &>/dev/null; then # $pgsql_auth_type -> CentOS/RHEL
            echo "${cyan}Some or all of the prerequisites are not installed." \
                "Until they are all installed and set up, all options to run" \
                "Botler have been disabled.${nc}"
            echo "1. Download/update Botler"

            if ! hash psql &>/dev/null; then
                echo "2. Install Postgres ${red}(Not installed)${nc}"
            else
                echo "2. Install Postgres ${green}(Already installed)${nc}"
            fi
            
            if (! hash node || ! hash npm) &>/dev/null; then
                echo "3. Install Node.js (will also perform the actions of" \
                    "option 4) ${red}(Not installed)${nc}"
            else
                echo "3. Install Node.js (will also perform the actions of" \
                    "option 4) ${green}(Already installed)${nc}"
            fi

            if [[ ! -d node_modules ]] &>/dev/null; then
                echo "4. Install required packages and dependencies" \
                    "${red}(Already installed)${nc}"
            else
                echo "4. Install required packages and dependencies" \
                    "${green}(Already installed)${nc}"
            fi

            if [[ ! -f src/botconfig.json ]]; then
                echo "5. Set up botconfig.json ${red}(Not setup)${nc}"
            else
                echo "5. Set up botconfig.json ${green}(Already setup)${nc}"
            fi

            if [[ ! -f ormconfig.json ]]; then
                echo "6. Set up ormconfig.json ${red}(Not setup)${nc}"
            else
                echo "6. Set up ormconfig.json ${green}(Already setup)${nc}"
            fi

            if [[ ! -d out ]]; then
                echo "7. Compile code ${red}(Not compiled)${nc}"
            else
                echo "7. Compile code ${green}(Already compiled)${nc}"
            fi
            
            if [[ $database_exist && $database_user_exist && ! $pgsql_auth_type ]]; then # $pgsql_auth_type -> CentOS/RHEL
                echo "8. Configure Postgres database ${green}(Already setup)${nc}"
            elif [[ $database_exist || $database_user_exist || ! $pgsql_auth_type ]]; then # $pgsql_auth_type -> CentOS/RHEL
                echo "8. Configure Postgres database ${yellow}(Partially setup)${nc}"
            else
                echo "8. Configure Postgres database ${red}(Not setup)${nc}"
            fi

            echo "9. Stop and exit script"
            read option
            case "$option" in
                1)
                    export home
                    export files
                    export botler_service
                    export botler_service_content
                    #wget -qN https://raw.githubusercontent.com/Botler-Dev/Installer/master/download-update.sh
                    wget -qN https://raw.githubusercontent.com/Botler-Dev/Installer/tarball/download-update.sh
                    chmod +x download-update.sh && ./download-update.sh
                    exec "$master_installer"
                    ;;
                2)
                    bash postgres-installer.sh
                    clear
                    ;;
                3)
                    export option
                    bash odejs-installer.sh
                    clear
                    ;;
                4)
                    export option
                    bash nodejs-installer.sh
                    clear
                    ;;
                5)
                    export botler_service_status
                    bash botconfig-setup.sh
                    clear
                    ;;
                6)
                    export botler_service_status
                    bash ormconfig-setup.sh
                    clear
                    ;;
                7)
                    clear
                    if [[ ! -f src/botconfig.json ]]; then
                        echo "${yellow}'botconfig.json' doesn't exist. Before" \
                            "compiling the code, create 'botconfig.json' via" \
                            "option 5 on the installer menu.${nc}"
                        continue
                    fi

                    printf "We will now compile the botler code. "
                    read -p "Press [Enter] to continue."
                    echo "Compiling code..."
                    tsc || {
                        echo "${red}Failed to compile code${nc}" >&2
                        read -p "Press [Enter] to return to the installer menu"
                        clear
                        continue
                    }

                    echo -e "\n${cyan}If there are any errors, resolve whatever issue is" \
                        "causing them, then attempt to compile the code again\n${nc}"

                    read -p "Press [Enter] to return to the installer menu"
                    clear
                    ;;
                8)
                    clear
                    if ! hash psql &>/dev/null; then
                        echo "${yellow}Postgres is not installed. Postgres" \
                            "must be installed before it can be configured.${nc}"
                        continue
                    fi
                    printf "We will now configure the Postgres database. "
                    read -p "Press [Enter] to continue."

                    echo "Creating database user 'Botler'..."
                    if [[ $database_exist ]]; then
                        echo "${cyan}Role 'Botler' already exists${nc}"
                    else
                        sudo -u postgres -H sh -c "createuser -P Botler" || {
                            echo "${red}Failed to create the database user" \
                                "'Botler'${nc}" >&2
                            read -p "Press [Enter] to return to the installer menu"
                            clear
                            continue
                        }
                    fi

                    echo "Creating database for Botler..."
                    if [[ $database_user_exist ]]; then
                        echo "${cyan}Database 'Botler_DB' already exist${nc}"
                    else
                        sudo -u postgres -H sh -c "createdb -O Botler Botler_DB" || {
                            echo "${red}Failed to create a database for Botler${nc}" >&2
                            create_failed=true
                        }
                    fi

                    # Whole if statement -> CentOS/RHEL
                    echo "Modifying authentication method from ident to md5..."
                    if [[ $pgsql_auth_type ]]; then
                        # TODO: There might be more than one possible location
                        sed -i.bak 's/ident$/md5/g' /var/lib/pgsql/12/data/pg_hba.conf
                        
                        if [[ $(systemctl is-active postgresql-12) ]]; then
                            echo "Restarting postgresql-12..."
                            systemctl restart postgresql-12 || {
                                echo "${red}Failed to restart postgresql-12" >&2
                                echo "${cyan}You will need to manually restart it" \
                                    "to apply any changes to the config files"
                            }
                        fi
                    else 
                        echo "Authentication already uses method md5"
                    fi

                    if [[ ! $create_failed ]]; then
                        echo -e "\n${green}Postgres database has been configured${nc}"
                    else
                        echo -e "\n"
                    fi
                    read -p "Press [Enter] to return to the installer menu"
                    clear
                    ;;
                9)
                    clean_exit "0"
                    ;;
                *)
                    clear
                    echo "${red}Invalid input: '$option' is not a valid" \
                        "option${nc}" >&2
                    continue
                    ;;
            esac
        # Botler run mode options
        else
            echo "${cyan}Note: Running Botler in the same mode it's currently" \
                "running in, will restart the bot${nc}"
            if [[ $botler_service_startup = 0 && -f $botler_service &&
                    $botler_service_status = "active" ]]; then
                echo "1. Download/update Botler"
                echo "2. Run Botler in the background"
                echo "3. Run Botler in the background with auto-restart${green}" \
                    "(Running in this mode)${nc}"
            elif [[ $botler_service_startup = 0 && -f $botler_service &&
                    $botler_service_status != "active" ]]; then
                echo "1. Download/update Botler"
                echo "2. Run Botler in the background"
                echo "3. Run Botler in the background with auto-restart${yellow}" \
                    "(Setup to use this mode)${nc}"
            elif [[ -f $botler_service && $botler_service_status = "active" ]]; then
                echo "1. Download/update Botler"
                echo "2. Run Botler in the background ${green}(Running in" \
                    "this mode)${nc}"
                echo "3. Run Botler in the background with auto-restart"
            elif [[ -f $botler_service && $botler_service_status != "active" ]]; then
                echo "1. Download/update Botler"
                echo "2. Run Botler in the background ${yellow}(Setup to" \
                    "use this mode)${nc}"
                echo "3. Run Botler in the background with auto-restart"
            # If this occurs, that means that 'botler.service' has not been
            # created for some reason
            else
                echo "1. Download/update Botler"
                echo "2. Run Botler in the background"
                echo "3. Run Botler in the background with auto-restart"
            fi

            echo "4. Stop Botler"
            echo "5. Advanced options"
            echo "6. Stop and exit script"
            read option
            case "$option" in
                1)
                    export home
                    export files
                    export botler_service
                    export botler_service_content
                    #wget -qN https://raw.githubusercontent.com/Botler-Dev/Installer/master/download-update.sh
                    wget -qN https://raw.githubusercontent.com/Botler-Dev/Installer/tarball/download-update.sh
                    chmod +x download-update.sh && ./download-update.sh
                    exec "$master_installer"
                    ;;
                2)
                    export home
                    export files
                    export botler_service_status
                    export botler_service_startup
                    bash installers/Linux_Universal/b-start-modes/run-in-background.sh
                    clear
                    ;;
                3)
                    export home
                    export files
                    export botler_service_status
                    export botler_service_startup
                    bash installers/Linux_Universal/b-start-modes/run-in-background-auto-restart.sh
                    clear
                    ;;
                4)
                    export botler_service_status
                    bash installers/Linux_Universal/b-stop.sh
                    clear
                    ;;
                5)
                    bash installers/Linux_Universal/postgres-open-close.sh
                    clear
                    ;;
                6)
                    clean_exit "0"
                    ;;
                *)
                    clear
                    echo "${red}Invalid input: '$option' is not a valid" \
                        "option${nc}" >&2
                    continue
                    ;;
            esac
        fi
    done
