#!/bin/bash

# Play an error beep if it exits with an error
trap error_beep exit 1

# Function to beep on an exit 1
error_beep() {
    echo -en "\007"
    tput cnorm
}

# Store the user in a variable
if [ -z "${USER}" ]; then
    USER="$(id -un)"
fi

#$#######################################
# SET KIIRONODE.SETTINGS DEFAULT VALUES #
##$######################################

# The values are used when the kiironode.settings file is first created

USER_HOME=$(getent passwd $USER | cut -d: -f6)

# FILE AND FOLDER LOCATIONS
KIIRO_DATA_LOCATION=$USER_HOME/.kiirocoin/

# OTHER SETTINGS
KIIRO_MAX_CONNECTIONS=250
SM_AUTO_QUIT=20

# SYSTEM VARIABLES
KIIRO_INSTALL_LOCATION=/usr/bin

# Set these values so KiiroNode Setup can still run in color
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_LIGHT_RED='\e[1;31m'
COL_LIGHT_BLUE='\e[0;94m'
COL_LIGHT_CYAN='\e[1;96m'
COL_BOLD_WHITE='\e[1;37m'
COL_LIGHT_YEL='\e[1;33m'
TICK="  [${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="  [${COL_LIGHT_RED}✗${COL_NC}]"
WARN="  [${COL_LIGHT_RED}!${COL_NC}]"
INFO="  [${COL_BOLD_WHITE}i${COL_NC}]"
SKIP="  [${COL_BOLD_WHITE}-${COL_NC}]"
EMPTY="  [ ]"
INDENT="     "
# shellcheck disable=SC2034
DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
OVER="  \\r\\033[K"

# Dashboard colors
dbcol_bwht="\e[97m" # Bright White
dbcol_bred="\e[91m" # Bright Red
dbcol_bylw="\e[93m" # Bright Yellow
dbcol_bgrn="\e[92m" # Bright Green
dbcol_bblu="\e[94m" # Bright Blue
#########
dbcol_bld="\e[1m" # Bold Text
dbcol_rst="\e[0m" # Text Reset
#########
dbcol_bld_bwht="\e[1;37m" # Bold Bright White Text

KIIRO_SETTINGS_LOCATION=$USER_HOME/.kiirocoin
KIIRO_SETTINGS_FILE=$KIIRO_SETTINGS_LOCATION/kiironode.settings

# This variable stores the approximate amount of space required to download the entire Kiirocoin blockchain
# This value needs updating periodically as the size of the blockchain increases over time
# It is used during the disk space check to ensure there is enough space on the drive to download the Kiirocoin blockchain.
# (Format date like so - e.g. "October 2023"). This is the approximate date when these values were updated.
KIIRO_DATA_REQUIRED_DATE="October 2023"
KIIRO_DATA_REQUIRED_HR="250Mb"
KIIRO_DATA_REQUIRED_KB="250000"

# Set some global variables here
PKG_MANAGER="apt-get"
# A variable to store the command used to update the package cache
UPDATE_PKG_CACHE="${PKG_MANAGER} update"
# The command we will use to actually install packages
PKG_INSTALL=("${PKG_MANAGER}" -qq --no-install-recommends install)
# grep -c will return 1 if there are no matches. This is an acceptable condition, so we OR TRUE to prevent set -e exiting the script.
PKG_COUNT="${PKG_MANAGER} -s -o Debug::NoLocking=true upgrade | grep -c ^Inst || true"
SETUP_DEPS=(wget unzip jq sysstat)

txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtylw=$(tput setaf 3) # Yellow
txtblu=$(tput setaf 4) # Blue
txtpur=$(tput setaf 5) # Purple
txtcyn=$(tput setaf 6) # Cyan
txtwht=$(tput setaf 7) # White

txtbred=$(tput setaf 9)  # Bright Red
txtbgrn=$(tput setaf 10) # Bright Green
txtbylw=$(tput setaf 11) # Bright Yellow
txtbblu=$(tput setaf 12) # Bright Blue
txtbpur=$(tput setaf 13) # Bright Purple
txtbcyn=$(tput setaf 14) # Bright Cyan
txtbwht=$(tput setaf 15) # Bright White

txtrst=$(tput sgr0) # Text reset.
txtbld=$(tput bold) # Set bold mode

# whiptail dialog dimensions: 20 rows and 70 chars width assures to fit on small screens and is known to hold all content.
r=24
c=70

# GitHub Release: (do not change these)
KIIRO_GITHUB_URL=https://github.com/Kiirocoin/kiiro/releases/download/v1.0.0.4/kiirocoin-1.0.0.4-linux-18.04.zip
KIIRONODE_URL=https://raw.githubusercontent.com/kiirodev/kiiro-node-1-click-install/feature/kiironode/kiironode.sh

# SYSTEM SERVICE FILES: (do not change these)
KIIRO_SYSTEMD_SERVICE_FILE=/etc/systemd/system/kiirocoind.service

# KIIROCOIN NODE FILES: (do not change these)
KIIRO_CONF_FILE=~/.kiirocoin/kiirocoin.conf

# KIIROCOIN VERSION: (do not change these)
KIIRO_LATEST_VERSION=v1.0.0.4

MODEL=$(grep -oP '(?<=PRETTY_NAME=).*' /etc/os-release | tr -d '""')
MODELMEM=$(free -h --giga  | awk '/^Mem:/{print $2}')

#####################################################################################################
### FUNCTIONS
#####################################################################################################

# Display KiiroNode help screen
display_help() {
    echo ""
    echo "  ╔═════════════════════════════════════════════════════════╗"
    echo "  ║                                                         ║"
    echo "  ║                   ${txtbld}K I I R O N O D E    ${txtrst}                 ║"
    echo "  ║                                                         ║"
    echo "  ║       Setup and manage your Kiirocoin Masternode        ║"
    echo "  ║                                                         ║"
    echo "  ╚═════════════════════════════════════════════════════════╝"
    echo ""
}

test_dpkg_lock() {
    i=0
    # fuser is a program to show which processes use the named files, sockets, or filesystems
    # So while the lock is held,
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
        # we wait half a second,
        sleep 0.5
        # increase the iterator,
        ((i = i + 1))
    done
    # and then report success once dpkg is unlocked.
    return 0
}

banner() {
    clear
    echo -e "${txtylw}
                                                                
                                                                
                   ${txtylw}--                                           
                   ${txtylw}---     ${txtrst}#######                              
                   ${txtylw}---   ${txtrst}################                       
                   ${txtylw}----   ${txtrst}###################                   
             ${txtrst}###   ${txtylw}----   ${txtrst}####################                  
           ${txtrst}#####   ${txtylw}-----   ${txtrst}###############         ${txtylw}---------    
          ${txtrst}#####   ${txtylw}------   ${txtrst}##########        ${txtylw}--------------     
        ${txtrst}#######   ${txtylw}------   ${txtrst}########     ${txtylw}---------------         
       ${txtrst}########   ${txtylw}------   ${txtrst}#####    ${txtylw}---------------             
      ${txtrst}#########   ${txtylw}------    ${txtrst}#    ${txtylw}---------------    ${txtrst}###         
     ${txtrst}#########   ${txtylw}--------      -------------     ${txtrst}#######        
    ${txtrst}##########   ${txtylw}--------    -------------    ${txtrst}###########       
    ${txtrst}##########   ${txtylw}--------  ------------     ${txtrst}#############       
   ${txtrst}##########   ${txtylw}--------- ------------   ${txtrst}#################      
   ${txtrst}##########   ${txtylw}--------------------   ${txtrst}###################      
   ${txtrst}#########   ${txtylw}-------------------    ${txtrst}####################      
   ${txtrst}#########   ${txtylw}------------------      ${txtrst}###################      
   ${txtrst}########   ${txtylw}------------------------    ${txtrst}################      
   ${txtrst}#######    ${txtylw}--------------------------    ${txtrst}##############      
   ${txtrst}#######   ${txtylw}-----------------------------    ${txtrst}############      
    ${txtrst}#####   ${txtylw}--------------------------------   ${txtrst}##########       
    ${txtrst}####   ${txtylw}----------------------------------   ${txtrst}#########       
     ${txtrst}##    ${txtylw}---------              ------------   ${txtrst}#######        
          ${txtylw}--------    ${txtrst}##########      ${txtylw}---------   ${txtrst}#####         
         ${txtylw}--------    ${txtrst}###############     ${txtylw}------    ${txtrst}###          
        ${txtylw}-------    ${txtrst}####################   ${txtylw}------   ${txtrst}##           
       ${txtylw}------    ${txtrst}########################   ${txtylw}----                
     ${txtylw}------    ${txtrst}###########################   ${txtylw}----               
    ${txtylw}----      ${txtrst}#############################   ${txtylw}---               
   ${txtylw}--           ${txtrst}############################   ${txtylw}--               
                   ${txtrst}#######################                      
                         ${txtrst}###########                            
                                                                "
    echo -e "${txtrst} \n"
}

is_command() {
    # Checks to see if the given command (passed as a string argument) exists on the system.
    # The function returns 0 (success) if the command exists, and 1 if it doesn't.
    local check_command="$1"

    command -v "${check_command}" >/dev/null 2>&1
}

# Tell the user where this script is running from
where_are_we() {
    if [ "$KIIRO_RUN_LOCATION" = "local" ]; then
        printf "%b KiiroNode is running locally.\\n" "${INFO}"
        printf "\\n"
    fi
    if [ "$KIIRO_RUN_LOCATION" = "remote" ]; then
        printf "%b KiiroNode is running remotely.\\n" "${INFO}"
        printf "\\n"
    fi
}

# Function to install masternode
install_masternode() {
    banner
    display_help

    # Lookup the external IP
    lookup_external_ip

    printf "%b If your VPS IP is not correct or is blank, please contact Kiirocoin\\n" "${INDENT}"
    printf "%b Support team for assistance with editing kiirocoin.conf after this install\\n" "${INDENT}"

    # Check if kiirocoin is already installed and running
    kiirocoin_check
    # Stop kiirocoin if already installed and running
    kiirocoin_stop_running
    if bls; then
        # Create/update kiirocoin.conf file
        create_kiirocoin_conf

        # Install/upgrade kiirocoin Core
        kiirocoin_do_install

        # Create kiirocoind.service
        kiirocoin_create_service

        # Start kiirocoind.service
        restart_service "kiirocoind"

        # Sleep to allow service to start
        sleep_timer

        closing_banner_message
    fi
}

# Function to upgrade masternode release
upgrade_masternode() {
    banner
    display_help

    # Check if kiirocoin is already installed and running
    kiirocoin_check
    # Stop kiirocoin if already installed and running
    kiirocoin_stop_running

    # Install/upgrade kiirocoin Core
    kiirocoin_do_install

    if [ $KIIRO_HAS_SERVICE == "YES" ] && [ $KIIRO_STATUS == "running_as_service" ]; then
        # Start kiirocoind.service
        restart_service "kiirocoind"
    elif [ $KIIRO_HAS_SERVICE == "NO" ] && [ $KIIRO_STATUS == "running_as_daemon" ]; then
        # Run kiirocoind
        if whiptail --backtitle "" --title "INSTALL AS SERVICE" --yesno "Would you like to run Kiirocoin Core as a service?\\n\\nThis ensures that your Kiirocoin Masternode starts automatically\\nat boot and will restart automatically if it crashes for some\\nreason. This is the preferred way to run a Kiirocoin Masternode\\nand helps to ensure it is kept running 24/7.\\n" "14" "${c}"; then
            kiirocoin_create_service
        else
            start_daemon
        fi
    fi

    # Sleep to allow service to start
    sleep_timer

    closing_banner_message
}

run_evoznode_status() {
    banner
    display_help
    local str="Running kiirocoin-cli evoznode status"
    printf "%b %s\\n" "${INFO}" "${str}"
    sudo kiirocoin-cli evoznode status | jq
    printf "%b If you do not see ready then run the command again in 30 minutes.\\n" "${INDENT}"
    printf "%b Reach out to us on Discord if you need any help\\n" "${INDENT}"
    printf "%b https://discord.gg/g88D2RP9\\n" "${INDENT}"
}

query_kiirocoin_chain() {
    KIIRO_NETWORK_CHAIN=""
    local kiiro_network_chain_query
    kiiro_network_chain_query=$(sudo $KIIRO_CLI getblockchaininfo 2>/dev/null | grep -m1 chain | cut -d '"' -f4)
    if [ "$kiiro_network_chain_query" != "" ]; then
        KIIRO_NETWORK_CHAIN=$kiiro_network_chain_query
    fi

    KIIRO_NETWORK_CURRENT="MAINNET"
    KIIRO_NETWORK_CURRENT_LIVE="YES"
}

check_kiirocoin_release() {
    # Check Github repo to find the version number of the latest Kiirocoin Core release
    str="Checking GitHub repository for the latest Kiirocoin Core release..."
    printf "%b %s" "${INFO}" "${str}"
    KIIRO_VER_RELEASE=v$(curl -sfL https://api.github.com/repos/kiirocoin/kiiro/releases/latest | jq -r ".tag_name" | sed 's/v//g')

    # If can't get Github version number
    if [ "$KIIRO_VER_RELEASE" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for new version of Kiirocoin Core. Is the Internet down?.\\n" "${CROSS}"
        printf "\\n"
        printf "%b Kiirocoin Core cannot be upgraded. Skipping...\\n" "${INFO}"
        printf "\\n"
        KIIRO_DO_INSTALL=NO
        KIIRO_INSTALL_TYPE="none"
        KIIRO_UPDATE_AVAILABLE=NO
        false
        return     
    else
        printf "%b%b %s Found: ${KIIRO_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        sed -i -e "/^KIIRO_VER_RELEASE=/s|.*|KIIRO_VER_RELEASE=\"$KIIRO_VER_RELEASE\"|" $KIIRO_SETTINGS_FILE
        if [ "$REQUEST_KIIRO_RELEASE_TYPE" = "" ]; then
            INSTALL_KIIRO_RELEASE_TYPE="release"
        fi
    fi
    return
}

lookup_external_ip() {

    # update external IP address and save to settings file
    str="Looking up external IP address..."
    printf "  %b %s" "${INFO}" "${str}"
    IP4_EXTERNAL_QUERY=$(dig @resolver4.opendns.com myip.opendns.com +short)
    if [ $IP4_EXTERNAL_QUERY != "" ]; then
        IP4_EXTERNAL=$IP4_EXTERNAL_QUERY
    fi
    printf "  %b%b %s %s\\n" "  ${OVER}" "${TICK}" "${str}" "${IP4_EXTERNAL}"
    printf "\\n"

}

sleep_timer() {
    local str="Sleeping for 10 seconds to allow Kiirocoin service to start..."
    printf "%b %s" "${INFO}" "${str}"
    sleep 10
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
}

kiirocoin_do_install() {
    echo ""
    printf " =============== Install: Kiirocoin ===================================\\n\\n"

    if compgen -G "kiirocoin-*-linux-18.04.zip" >/dev/null; then
        str="Deleting old Kiirocoin Core zip files from folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f kiirocoin-*-linux-18.04.zip
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Downloading latest Kiirocoin Core binary from GitHub
    str="Downloading Kiirocoin Core v1.0.0.4 from Github repository..."
    printf "%b %s" "${INFO}" "${str}"
    sudo wget -q $KIIRO_GITHUB_URL

    # If the command completed without error, then assume downloaded correctly
    if [ $? -eq 0 ]; then
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        printf "\\n"
        printf "%b%b ${txtred}ERROR: Kiirocoin Core Download Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b The new version of Kiirocoin Core could not be downloaded. Perhaps the download URL has changed?\\n" "${INFO}"
        false
        return
    fi
    str="Extracting Kiirocoin Core v1.0.0.4 ..."
    printf "%b %s" "${INFO}" "${str}"
    unzip -qq kiirocoin-1.0.0.4-linux-18.04.zip -x kiirocoin-tx kiirocoin-qt
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    chmod +x kiirocoind
    chmod +x kiirocoin-cli

    str="Moving files to /usr/bin ..."
    printf "%b %s" "${INFO}" "${str}"
    sudo mv -f kiirocoin-cli /usr/bin && sudo mv -f kiirocoind /usr/bin
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    printf "\\n"

    str="Deleting Kiirocoin Core zip file from folder..."
    printf "%b %s" "${INFO}" "${str}"
    rm -f kiirocoin-1.0.0.4-linux-18.04.zip
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

}

install_dependent_packages() {
    # Install packages passed in via argument array
    # No spinner - conflicts with set -e
    declare -a installArray

    # For each package, check if it's already installed (and if so, don't add it to the installArray)
    for i in "$@"; do
        printf "%b Checking for %s..." "${INFO}" "${i}"
        if dpkg-query -W -f='${Status}' "${i}" 2>/dev/null | grep "ok installed" &>/dev/null; then
            printf "%b  %b Checking for %s\\n" "${OVER}" "${TICK}" "${i}"
        else
            printf "%b  %b Checking for %s (will be installed)\\n" "${OVER}" "${INFO}" "${i}"
            installArray+=("${i}")
        fi
    done
    # If there's anything to install, install everything in the list.
    if [[ "${#installArray[@]}" -gt 0 ]]; then
        test_dpkg_lock
        printf "%b Processing %s install(s) for: %s, please wait...\\n" "${INFO}" "${PKG_MANAGER}" "${installArray[*]}"
        printf '%*s\n' "$columns" '' | tr " " -
        "${PKG_INSTALL[@]}" "${installArray[@]}" &>/dev/null
        printf '%*s\n' "$columns" '' | tr " " -
        return
    fi
}

bls() {
    # Ask the user what size of swap file they want
    blsSecret=$(whiptail --inputbox "\\nPlease enter BLS generated Secret" "10" "${c}" "" --title "BLS Secret" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus == 0 ]; then
        if [ -z "$blsSecret" ]; then
            printf "%b No BLS secret entered.\\n" "${WARN}"
            printf "\\n"
            false
            return
        fi
        length=$(expr length ${blsSecret//[[:blank:]]/})
        if [ $length != 64 ]; then
            printf "%b Invalid BLS secret entered.\\n" "${WARN}"
            false
            return
        fi
        printf "%b BLS secret entered: %s\\n" "${TICK}" "${blsSecret}"
        printf "\\n"
    else
        printf "%b %bYou cancelled inputing your secret.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        false
        return
    fi
}

kiirocoin_create_service() {
    printf " =============== Install: Kiirocoin daemon service =====================\\n\\n"
    if [ -f $KIIRO_SYSTEMD_SERVICE_FILE ]; then
        stop_service "kiirocoind"
        disable_service "kiirocoind"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        str="Sleeping for 10 seconds to allow Kiirocoin service to stop..."
        printf "%b %s" "${INFO}" "${str}"
        sleep 10
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        str="Deleting Kiirocoin daemon service file..."
        printf "%b %s" "${INFO}" "${str}"
        sudo rm $KIIRO_SYSTEMD_SERVICE_FILE
        sudo systemctl daemon-reload
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    rpcuser=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
    rpcpassword=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)

    str="Creating Kiirocoin service file: ${KIIRO_SYSTEMD_SERVICE_FILE} ... "
    printf "%b %s" "${INFO}" "${str}"

    cat <<EOF >$KIIRO_SYSTEMD_SERVICE_FILE
# Install this in /etc/systemd/system/
# See below for more details and options
# Then run following to always start:
# systemctl enable kiirocoind
#
# and the following to start immediately:
# systemctl start kiirocoind

[Unit]
Description=Kiirocoin daemon
After=network.target

[Service]
ExecStart=kiirocoind

# Process management
####################

Type=forking
PIDFile=/root/.kiirocoin/kiirocoind.pid
Restart=on-failure

# Directory creation and permissions
####################################

# Run as root:root or <youruser>
User=root
Group=root

# Hardening measures
####################

# Provide a private /tmp and /var/tmp.
PrivateTmp=true

# Use a new /dev namespace only populated with API pseudo devices
# such as /dev/null, /dev/zero and /dev/random.
PrivateDevices=true

# Deny the creation of writable and executable memory mappings.
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    printf "\\n"

    # Enable the service to run at boot
    enable_service "kiirocoind"
    sudo systemctl daemon-reload

}

create_kiirocoin_conf() {

    local str

    printf " =============== Creating: kiirocoin.conf ==============================\\n\\n"
    # Create a new kiirocoin.conf file
    str="Creating ${KIIRO_CONF_FILE} file..."
    printf "%b %s" "${INFO}" "${str}"

    # create .kiirocoin folder if it does not exist
    if [ ! -d ~/.kiirocoin ]; then
        str="Creating ~/.kiirocoin folder..."
        printf "\\n%b %s" "${INFO}" "${str}"
        sudo mkdir ~/.kiirocoin
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    elif [ -f $KIIRO_CONF_FILE ]; then
        sudo rm $KIIRO_CONF_FILE
    fi
    rpcuser=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
    rpcpassword=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
    sudo touch $KIIRO_CONF_FILE

    cat <<EOF >$KIIRO_CONF_FILE
#----
rpcuser=${rpcuser}
rpcpassword=${rpcpassword}
rpcallowip=127.0.0.1
rpcport=9000
port=8999
#----
listen=1
server=1
daemon=1
logtimestamps=1
txindex=1
#----
znode=1
externalip=${IP4_EXTERNAL//[[:blank:]]/}:8999
znodeblsprivkey=${blsSecret//[[:blank:]]/}
EOF
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    printf "\\n"
}

closing_banner_message() {
    local str

    printf "\\n"
    printf " =======================================================================\\n"
    printf " ===== ${txtbgrn}Congratulations - Your Kiiro Masternode has been installed!${txtrst} =====\\n"
    printf " =======================================================================\\n\\n"

    str="Running kiirocoin-cli evoznode status"
    printf "%b %s\\n" "${INFO}" "${str}"
    sudo kiirocoin-cli evoznode status | jq
    printf "%b If you do not see ready then run the following command again in 30 minutes:\\n" "${INDENT}"
    printf "%b If you are receiving an error, you may have not properly registered Masternode or entered wrong information in beginning of install script\\n" "${INDENT}"
    printf "%b Reach out to us on Discord if you need any help\\n" "${INDENT}"
    printf "%b https://discord.gg/g88D2RP9\\n" "${INDENT}"
}

kiirocoin_check() {
    str="Is Kiirocoin Core already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ -f "/usr/bin/kiirocoind" ]; then
        KIIRO_STATUS="installed"
        printf "%b%b %s YES! [ Kiirocoin Install Detected. ] \\n" "${OVER}" "${TICK}" "${str}"
    else
        KIIRO_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
    fi

    if [ -f "$KIIRO_SYSTEMD_SERVICE_FILE" ]; then
        KIIRO_HAS_SERVICE="YES"
    else
        KIIRO_HAS_SERVICE="NO"
    fi
    # Next let's check if Kiirocoin daemon is running
    str="Is Kiirocoin Core running?..."
    printf "%b %s" "${INFO}" "${str}"

    # Check if kiirocoin daemon is running as a service.
    if [ $(systemctl is-active "kiirocoind") == 'active' ]; then
        printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        KIIRO_STATUS="running_as_service"
    else
        # Check if kiirocoind is running (but not as a service).
        if [ "" != "$(pgrep -a kiirocoind)" ]; then
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
            printf "\\n"
            printf "%b %bWARNING: kiirocoind is not currently running as a service%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b KiiroNode Setup can help you to setup kiirocoind to run as a service.\\n" "${INDENT}"
            printf "%b This ensures that your Kiirocoin Masternode starts automatically at boot and\\n" "${INDENT}"
            printf "%b will restart automatically if it crashes for some reason. This is the preferred\\n" "${INDENT}"
            printf "%b way to run a kiirocoin Masternode and helps to ensure it is kept running 24/7.\\n" "${INDENT}"
            printf "\\n"
            KIIRO_PATH="$(pgrep -a kiirocoind | awk '{print $2}' | rev | cut -d'/' -f2- | rev)"
            if [ $KIIRO_PATH == "kiirocoind" ]; then
                KIIRO_PATH="/usr/bin"
            fi
            KIIRO_STATUS="running_as_daemon"
        else
            KIIRO_STATUS="notrunning"
            printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        fi
    fi
}

kiirocoin_stop_running() {
    # Check if kiirocoin is already installed and running
    if [ $KIIRO_HAS_SERVICE == "YES" ] && [ $KIIRO_STATUS == "running_as_service" ]; then
        stop_service "kiirocoind"
        str="Sleeping for 10 seconds to allow Kiirocoin service to stop..."
        printf "%b %s" "${INFO}" "${str}"
        sleep 10
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    elif [ $KIIRO_HAS_SERVICE == "NO" ] && [ $KIIRO_STATUS == "running_as_daemon" ]; then
        stop_daemon
        str="Sleeping for 10 seconds to allow Kiirocoin daemon to stop..."
        printf "%b %s" "${INFO}" "${str}"
        sleep 10
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
}

# Start daemon
start_daemon() {
    # Local, named variables
    local str="Starting kiirocoind daemon"
    printf "%b %s..." "${INFO}" "${str}"
    $KIIRO_PATH/kiirocoind -daemon &>/dev/null
    printf "%b%b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

stop_daemon() {
    # Local, named variables
    local str="Stopping kiirocoind daemon"
    printf "%b %s..." "${INFO}" "${str}"
    if [ -f "$KIIRO_PATH/kiirocoin-cli" ]; then
        $KIIRO_PATH/kiirocoin-cli stop &>/dev/null || true
    else
        kiirocoin-cli stop &>/dev/null || true
    fi
    printf "%b%b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

stop_service() {
    # Stop service passed in as argument.
    # Can softfail, as process may not be installed when this is called
    local str="Stopping ${1} service"
    printf "%b %s..." "${INFO}" "${str}"
    if is_command systemctl; then
        systemctl stop "${1}" &>/dev/null || true
    else
        service "${1}" stop &>/dev/null || true
    fi
    printf "%b%b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Start/Restart service passed in as argument
restart_service() {
    # Local, named variables
    local str="Restarting ${1} service"
    printf "%b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl; then
        # use that to restart the service
        systemctl restart "${1}" &>/dev/null
    fi
    printf "%b%b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Enable service so that it will start with next reboot
enable_service() {
    # Local, named variables
    local str="Enabling ${1} service to start on reboot"
    printf "%b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl; then
        # use that to enable the service
        systemctl enable "${1}" &>/dev/null
    fi
    printf "%b%b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Disable service so that it will not with next reboot
disable_service() {
    # Local, named variables
    local str="Disabling ${1} service"
    printf "%b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl; then
        # use that to disable the service
        systemctl disable "${1}" &>/dev/null
    else
        # Otherwise, use update-rc.d to accomplish this
        update-rc.d "${1}" disable &>/dev/null
    fi
    printf "%b%b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

check_service_active() {
    # If systemctl exists,
    if is_command systemctl; then
        # use that to check the status of the service
        systemctl is-active "${1}" &>/dev/null
    fi
}

ctrl_c() {
    EXIT_DASHBOARD=true
}

# Quit message - this functions runs automatically before exiting
quit_message() {

    EXIT_DASHBOARD=true

    kill $bg_cpu_stats_pid &>/dev/null
    rm -f "$cpu1_file" "$cpu2_file" "$avg_file"

    tput rmcup
    stty echo
    tput sgr0

    # Enabling line wrapping.
    printf '\e[?7h'

    #Set this so the backup reminder works
    NewInstall=False

    if [ "$auto_quit" = true ]; then
        echo ""
        printf "%b KiiroNode Dashboard quit automatically as it was left running\\n" "${INFO}"
        printf "%b for more than $SM_AUTO_QUIT minutes. You can increase the auto-quit duration\\n" "${INDENT}"
        printf "%b by changing the SM_AUTO_QUIT value in kiironode.settings\\n" "${INDENT}"
        echo ""
    fi

    # Showing the cursor.
    printf '\e[?25h'

    # Enabling line wrapping.
    printf '\e[?7h'

}

# Lookup disk usage, and store in kiironode.settings if present
update_disk_usage() {

    # Update current disk usage variables
    BOOT_DISKUSED_HR=$(df $USER_HOME -h --output=used | tail -n +2)
    BOOT_DISKUSED_KB=$(df $USER_HOME --output=used | tail -n +2)
    BOOT_DISKUSED_PERC=$(df $USER_HOME --output=pcent | tail -n +2)
    BOOT_DISKFREE_HR=$(df $USER_HOME -h --si --output=avail | tail -n +2)
    BOOT_DISKFREE_KB=$(df $USER_HOME --output=avail | tail -n +2)

    # Update current data disk usage variables
    KIIRO_DATA_TOTALDISK_KB=$(df $KIIRO_DATA_LOCATION | tail -1 | awk '{print $2}')
    KIIRO_DATA_DISKUSED_HR=$(df $KIIRO_DATA_LOCATION -h --output=used | tail -n +2)
    KIIRO_DATA_DISKUSED_KB=$(df $KIIRO_DATA_LOCATION --output=used | tail -n +2)
    KIIRO_DATA_DISKUSED_PERC=$(df $KIIRO_DATA_LOCATION --output=pcent | tail -n +2)
    KIIRO_DATA_DISKFREE_HR=$(df $KIIRO_DATA_LOCATION -h --si --output=avail | tail -n +2)
    KIIRO_DATA_DISKFREE_KB=$(df $KIIRO_DATA_LOCATION --output=avail | tail -n +2)

    # Kiirocoin mainnet disk used
    if [ -d "$KIIRO_DATA_LOCATION" ]; then
        KIIRO_DATA_DISKUSED_MAIN_HR=$(du -sh --exclude=testnet3 $KIIRO_DATA_LOCATION | awk '{print $1}')
        KIIRO_DATA_DISKUSED_MAIN_KB=$(du -sk --exclude=testnet3 $KIIRO_DATA_LOCATION | awk '{print $1}')
        KIIRO_DATA_DISKUSED_MAIN_PERC=$(echo "scale=2; ($KIIRO_DATA_DISKUSED_MAIN_KB*100/$KIIRO_DATA_TOTALDISK_KB)" | bc)
    else
        KIIRO_DATA_DISKUSED_MAIN_HR=""
        KIIRO_DATA_DISKUSED_MAIN_KB=""
        KIIRO_DATA_DISKUSED_MAIN_PERC=""
    fi
    # Trim white space from disk variables
    BOOT_DISKUSED_HR=$(echo -e " \t $BOOT_DISKUSED_HR \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
    BOOT_DISKUSED_KB=$(echo -e " \t $BOOT_DISKUSED_KB \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
    BOOT_DISKUSED_PERC=$(echo -e " \t $BOOT_DISKUSED_PERC \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
    BOOT_DISKFREE_HR=$(echo -e " \t $BOOT_DISKFREE_HR \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
    BOOT_DISKFREE_KB=$(echo -e " \t $BOOT_DISKFREE_KB \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
    KIIRO_DATA_DISKUSED_HR=$(echo -e " \t $KIIRO_DATA_DISKUSED_HR \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
    KIIRO_DATA_DISKUSED_KB=$(echo -e " \t $KIIRO_DATA_DISKUSED_KB \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
    KIIRO_DATA_DISKUSED_PERC=$(echo -e " \t $KIIRO_DATA_DISKUSED_PERC \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
    KIIRO_DATA_DISKFREE_HR=$(echo -e " \t $KIIRO_DATA_DISKFREE_HR \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
    KIIRO_DATA_DISKFREE_KB=$(echo -e " \t $KIIRO_DATA_DISKFREE_KB \t " | sed 's/^[ \t]*//;s/[ \t]*$//')

    # Get clean percentage (no percentage symbol)
    KIIRO_DATA_DISKUSED_PERC_CLEAN=$(echo -e " \t $KIIRO_DATA_DISKUSED_PERC \t " | cut -d'%' -f1)

    # Update kiironode.settings file it it exists
    if [ -f "$KIIRO_SETTINGS_FILE" ]; then
        sed -i -e "/^BOOT_DISKFREE_HR=/s|.*|BOOT_DISKFREE_HR=\"$BOOT_DISKFREE_HR\"|" $KIIRO_SETTINGS_FILE
        sed -i -e "/^BOOT_DISKFREE_KB=/s|.*|BOOT_DISKFREE_KB=\"$BOOT_DISKFREE_KB\"|" $KIIRO_SETTINGS_FILE
        sed -i -e "/^BOOT_DISKUSED_HR=/s|.*|BOOT_DISKUSED_HR=\"$BOOT_DISKUSED_HR\"|" $KIIRO_SETTINGS_FILE
        sed -i -e "/^BOOT_DISKUSED_KB=/s|.*|BOOT_DISKUSED_KB=\"$BOOT_DISKUSED_KB\"|" $KIIRO_SETTINGS_FILE
        sed -i -e "/^BOOT_DISKUSED_PERC=/s|.*|BOOT_DISKUSED_PERC=\"$BOOT_DISKUSED_PERC\"|" $KIIRO_SETTINGS_FILE
        sed -i -e "/^KIIRO_DATA_TOTALDISK_KB=/s|.*|KIIRO_DATA_TOTALDISK_KB=\"$KIIRO_DATA_TOTALDISK_KB\"|" $KIIRO_SETTINGS_FILE
        sed -i -e "/^KIIRO_DATA_DISKFREE_HR=/s|.*|KIIRO_DATA_DISKFREE_HR=\"$KIIRO_DATA_DISKFREE_HR\"|" $KIIRO_SETTINGS_FILE
        sed -i -e "/^KIIRO_DATA_DISKFREE_KB=/s|.*|KIIRO_DATA_DISKFREE_KB=\"$KIIRO_DATA_DISKFREE_KB\"|" $KIIRO_SETTINGS_FILE
        sed -i -e "/^KIIRO_DATA_DISKUSED_HR=/s|.*|KIIRO_DATA_DISKUSED_HR=\"$KIIRO_DATA_DISKUSED_HR\"|" $KIIRO_SETTINGS_FILE
        sed -i -e "/^KIIRO_DATA_DISKUSED_KB=/s|.*|KIIRO_DATA_DISKUSED_KB=\"$KIIRO_DATA_DISKUSED_KB\"|" $KIIRO_SETTINGS_FILE
        sed -i -e "/^KIIRO_DATA_DISKUSED_PERC=/s|.*|KIIRO_DATA_DISKUSED_PERC=\"$KIIRO_DATA_DISKUSED_PERC\"|" $KIIRO_SETTINGS_FILE
    fi
}

# displays the current Kiirocoin Core listening port
display_listening_port() {
    if [ "$KIIRO_STATUS" = "running" ] || [ "$KIIRO_STATUS" = "running_as_service" ] || [ "$KIIRO_STATUS" = "running_as_daemon" ] || [ "$KIIRO_STATUS" = "startingup" ]; then # Only show listening port if Kiirocoin Node is running or starting up
        if [ "$KIIRO_CONNECTIONS" = "" ]; then
            KIIRO_CONNECTIONS=0
            KIIRO_CONNECTED_PEERS_NEW=0
            KIIRO_CONNECTED_PEERS_OLD=0
        fi
        if [ $KIIRO_CONNECTIONS -le 8 ]; then # Only show if connection count is less or equal to 8 since it is clearly working with a higher count
            printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
            printf "  ║ KIIRO PORT     ║  " && printf "%-50s %-4s\n" "Listening Port: ${txtbylw}${KIIRO_LISTEN_PORT}${txtrst}" "   ║"
        fi
    fi
}

# Scrape the contents of kiirocoin.conf and store the sections in variables
scrape_kiirocoin_conf() {
    if [ -f "$KIIRO_CONF_FILE" ]; then
        # Initialize an associative array to store key-value pairs
        declare -A global_data
        # Read the file line by line
        while IFS= read -r line; do
            # Remove leading and trailing whitespace from the line
            line="${line##*([[:space:]])}"
            line="${line%%*([[:space:]])}"

            # Check if the line is not empty, does not start with #, and is not a section header
            if [[ ! -z "$line" && "$line" != \#* && ! "$line" =~ ^\[([^]]+)\]$ ]]; then
                # Check if the line contains an '=' character
                if [[ "$line" =~ = ]]; then
                    # Split the line into key and value
                    key="${line%%=*}"
                    value="${line#*=}"
                    # Trim leading and trailing whitespace from the value
                    value="${value##*([[:space:]])}"
                    value="${value%%*([[:space:]])}"
                    # Store the key-value pair in the associative array
                    global_data["$key"]="$value"
                fi
            fi
        done <$KIIRO_CONF_FILE

        # Store the key-value pairs for Global
        KIIRO_CONFIG_GLOBAL=$(
            echo -e "# Global key value pairs:"
            for key in "${!global_data[@]}"; do
                echo "$key=${global_data[$key]}"
            done
        )
    fi
}

# If Kiirocoin Core is not available it gets the value from kiirocoin.conf
kiirocoin_port_query() {

    # Get Kiirocoin Node listening port
    KIIRO_LISTEN_PORT_QUERY=$($KIIRO_CLI getnetworkinfo 2>/dev/null | jq .localaddresses[0].port)
    if [ "$KIIRO_LISTEN_PORT_QUERY" != "" ]; then
        KIIRO_LISTEN_PORT=$KIIRO_LISTEN_PORT_QUERY
        KIIRO_LISTEN_PORT_LIVE="YES" # We have a live value direct from kiirocoin-cli
    fi

    # If we failed to get a result from kiirocoin-cli for node, check kiirocoin.conf instead
    if [ "$KIIRO_LISTEN_PORT_QUERY" = "" ] || [ "$KIIRO_LISTEN_PORT_QUERY" = "null" ]; then
        # Make sure we have already scraped kiirocoin.conf
        if [ "$KIIRO_CONFIG_GLOBAL" = "" ]; then
            scrape_kiirocoin_conf
        fi
        KIIRO_LISTEN_PORT_GLOBAL=$(echo "$KIIRO_CONFIG_GLOBAL" | grep ^port= | cut -d'=' -f 2)
        KIIRO_LISTEN_PORT="8999"
        KIIRO_LISTEN_PORT_LIVE="NO" # Not a live value as retrieved from kiirocoin.conf
    fi
}

# Get the rpc credentials - rpcuser and rpcpassword - from kiirocoin.conf
kiirocoin_rpc_query() {

    if [ -f "$KIIRO_CONF_FILE" ]; then
        # Make sure we have already scraped kiirocoin.conf
        if [ "$KIIRO_CONFIG_GLOBAL" = "" ]; then
            scrape_kiirocoin_conf
        fi
        # Look up rpcuser from the global section of kiirocoin.conf
        RPC_USER=$(echo "$KIIRO_CONFIG_GLOBAL" | grep ^rpcuser= | cut -d'=' -f 2)
        # Look up rpcpassword from the global section of kiirocoin.conf
        RPC_PASSWORD=$(echo "$KIIRO_CONFIG_GLOBAL" | grep ^rpcpassword= | cut -d'=' -f 2)
        # Look up rpcport from the global section of kiirocoin.conf
        RPC_PORT=$(echo "$KIIRO_CONFIG_GLOBAL" | grep ^rpcport= | cut -d'=' -f 2)
        # Look up rpcbind from the global section of kiirocoin.conf
        RPC_BIND=$(echo "$KIIRO_CONFIG_GLOBAL" | grep ^rpcbind= | cut -d'=' -f 2)
    fi

}

# These are only set after the intitial OS check since they cause an error on MacOS
set_sys_variables() {
    local str

    str="Looking up system variables..."
    printf "%b %s" "${INFO}" "${str}"

    # Store total system RAM as variables
    RAMTOTAL_KB=$(cat /proc/meminfo | grep MemTotal: | tr -s ' ' | cut -d' ' -f2)
    RAMTOTAL_HR=$(free -h --si | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f2)

    # Store current total swap file size as variables
    SWAPTOTAL_KB=$(cat /proc/meminfo | grep SwapTotal: | tr -s ' ' | cut -d' ' -f2)
    SWAPTOTAL_HR=$(free -h --si | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f2)

    BOOT_DISKTOTAL_HR=$(df . -h --si --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    BOOT_DISKTOTAL_KB=$(df . --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    KIIRO_DATA_DISKTOTAL_HR=$(df $KIIRO_DATA_LOCATION -h --si --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    KIIRO_DATA_DISKTOTAL_KB=$(df $KIIRO_DATA_LOCATION --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')

    # Lookup disk usage, and update kiironode.settings if present
    update_disk_usage

    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    printf "\\n"
}

# Get RPC CREDENTIALS from kiirocoin.conf
check_kiiro_rpc_credentials() {

    if [ -f "$KIIRO_CONF_FILE" ]; then

        # Store the Kiirocoin Core verion as a single digit
        KIIRO_LOCAL_VER_DIGIT_QUERY="${KIIRO_LOCAL_VER:0:1}"
        if [ "$KIIRO_LOCAL_VER_DIGIT_QUERY" != "" ]; then
            KIIRO_LOCAL_VER_DIGIT=$KIIRO_LOCAL_VER_DIGIT_QUERY
        fi

        # Get RPC credentials
        kiirocoin_rpc_query

        if [ "$RPC_USER" != "" ] && [ "$RPC_PASSWORD" != "" ] && [ "$RPC_PORT" != "" ] && [ "$RPC_BIND" != "error" ]; then
            RPC_CREDENTIALS_OK="yes"
            printf "%b Kiirocoin RPC credentials found: ${TICK} Username     ${TICK} Password\\n" "${TICK}"
            printf "                                       ${TICK} RPC Port     ${TICK} Bind\\n\\n" "${TICK}"
        else
            RPC_CREDENTIALS_OK="NO"
            printf "%b %bERROR: Kiirocoin RPC credentials are missing:%b" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            if [ "$RPC_USER" != "" ]; then
                printf "${TICK}"
            else
                printf "${CROSS}"
            fi
            printf " Username     "
            if [ "$RPC_PASSWORD" != "" ]; then
                printf "${TICK}"
            else
                printf "${CROSS}"
            fi
            printf " Password\\n"
            printf "                                                  "
            if [ "$RPC_PORT" != "" ]; then
                printf "${TICK}"
            else
                printf "${CROSS}"
            fi
            printf " RPC Port     "
            if [ "$RPC_BIND" = "error" ]; then
                printf "${CROSS}"
            else
                printf "${TICK}"
            fi
            printf " Bind\n"
            printf "\\n"

        fi
    fi
}

# Import the kiironode.settings file it it exists
# check if kiironode.settings file exists
kiironode_import_settings() {

    local display_output="$1"

    if [ -f "$KIIRO_SETTINGS_FILE" ] && [ "$IS_KIIRO_SETTINGS_FILE_NEW" != "YES" ] && [ "$display_output" = "silent" ]; then

        source $KIIRO_SETTINGS_FILE

    elif [ -f "$KIIRO_SETTINGS_FILE" ] && [ "$IS_KIIRO_SETTINGS_FILE_NEW" != "YES" ]; then

        # The settings file exists, so source it
        str="Importing kiironode.settings file..."
        printf "%b %s" "${INFO}" "${str}"

        source $KIIRO_SETTINGS_FILE

        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        printf "\\n"
    fi
}

kiironode_create_settings() {
    local str

    # If the kiironode.settings file does not already exist, then create it
    if [ ! -f "$KIIRO_SETTINGS_FILE" ]; then

        # create .kiirocoin folder if it does not exist
        if [ ! -d "$KIIRO_SETTINGS_LOCATION" ]; then
            str="Creating ~/.kiirocoin folder..."
            printf "\\n%b %s" "${INFO}" "${str}"
            sudo mkdir $KIIRO_SETTINGS_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            IS_KIIROCOIN_SETTINGS_FOLDER_NEW="YES"
        fi

        # create kiironode.settings file
        kiironode_settings_create_update

        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        IS_KIIRONODE_SETTINGS_FILE_NEW="YES"

        # The settings file exists, so source it
        str="Importing kiironode.settings file..."
        printf "%b %s" "${INFO}" "${str}"
        source $KIIRO_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        printf "\\n"

        # Sets a variable to know that the kiironode.settings file has been created for the first time
        IS_KIIRO_SETTINGS_FILE_NEW="YES"

    fi
}

# This function actually creates or updates the kiironode.settings file
kiironode_settings_create_update() {

    if [ -f "$KIIRO_SETTINGS_FILE" ]; then
        str="Removing existing kiironode.settings file..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f KIIRO_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        recreate_kiironode_settings="yes"
    fi

    # create kiironode.settings file
    if [ "$recreate_kiironode_settings" = "yes" ]; then
        str="Recreating kiironode.settings file..."
    else
        str="Creating kiironode.settings file..."
    fi
    printf "%b %s" "${INFO}" "${str}"
    sudo touch $KIIRO_SETTINGS_FILE
    cat <<EOF >$KIIRO_SETTINGS_FILE
#!/bin/bash
# This settings file is used to store variables for KiiroNode Setup and KiiroNode Status Monitor

# KIIRONODE.SETTINGS FILE VERSION
KIIRO_SETTINGS_FILE_VER=$KIIRO_SETTINGS_FILE_VER_NEW
KIIRO_SETTINGS_FILE_VER_BRANCH=$KIIRO_SETTINGS_FILE_VER_BRANCH_NEW

############################################
####### FOLDER AND FILE LOCATIONS ##########
##########################################

# DEFAULT FOLDER AND FILE LOCATIONS
# If you want to change the default location of folders you can edit them here
# Important: Use the USER_HOME variable to identify your home folder location.

# KIIRO_SETTINGS_LOCATION=   [This value is set in the header of the setup script. Do not set it here.]
# KIIRO_SETTINGS_FILE=       [This value is set in the header of the setup script. Do not set it here.]

KIIRO_DATA_LOCATION=$KIIRO_DATA_LOCATION


#####################################
####### OTHER SETTINGS ##############
#####################################

# THis will set the max connections in the kiirobyte.conf file on the first install
# This value set here is also used when performing an unattended install
# (Note: If a kiirobyte.conf file already exists that sets the maxconnections already, the value here will be ignored)
KIIRO_MAX_CONNECTIONS=$KIIRO_MAX_CONNECTIONS

# Stop the KiiroNode Status Monitor automatically if it is left running. The default is 20 minutes.
# To avoid putting unnecessary strain on your device, it is inadvisable to run the Status Monitor for
# long periods. Enter the number of minutes before it exits automatically, or set to 0 to run indefinitely.
# e.g. To stop after 1 hour enter: 60 
SM_AUTO_QUIT=$SM_AUTO_QUIT

#############################################
####### SYSTEM VARIABLES ####################
#############################################

# IMPORTANT: DO NOT CHANGE ANY OF THESE VALUES. THEY ARE CREATED AND SET AUTOMATICALLY BY KiiroNode Setup and the Status Monitor.

# KIIROCOIN NODE LOCATION:
KIIRO_INSTALL_LOCATION=$KIIRO_INSTALL_LOCATION

# Do not change this.
# You can change the location of the blockchain data with the KIIRO_DATA_LOCATION variable above.
KIIRO_SETTINGS_LOCATION=\$USER_HOME/.kiirocoin

# KIIROCOIN NODE FILES: (do not change these)
KIIRO_CONF_FILE=\$KIIRO_SETTINGS_LOCATION/kiirocoin.conf 
KIIRO_CLI=\$KIIRO_INSTALL_LOCATION/kiirocoin-cli
KIIRO_DAEMON=\$KIIRO_INSTALL_LOCATION/kiirocoind

# SYSTEM SERVICE FILES: (do not change these)
KIIRO_SYSTEMD_SERVICE_FILE=$KIIRO_SYSTEMD_SERVICE_FILE

# Store Kiirocoin Core Installation details:
KIIRO_INSTALL_DATE="$KIIRO_INSTALL_DATE"
KIIRO_UPGRADE_DATE="$KIIRO_UPGRADE_DATE"
KIIRO_VER_RELEASE="$KIIRO_VER_RELEASE"
KIIRO_VER_LOCAL="$KIIRO_VER_LOCAL"
KIIRO_VER_LOCAL_CHECK_FREQ="$KIIRO_VER_LOCAL_CHECK_FREQ"
KIIRO_NETWORK_CURRENT="$KIIRO_NETWORK_CURRENT"

# KIIRONODE INSTALLATION DETAILS:
KIIRO_MONITOR_FIRST_RUN="$KIIRO_MONITOR_FIRST_RUN"
KIIRO_MONITOR_LAST_RUN="$KIIRO_MONITOR_LAST_RUN"

# Timer variables (these control the timers in the Status Monitor loop)
SAVED_TIME_10SEC="$SAVED_TIME_10SEC"
SAVED_TIME_1MIN="$SAVED_TIME_1MIN"
SAVED_TIME_15MIN="$SAVED_TIME_15MIN"
SAVED_TIME_1DAY="$SAVED_TIME_1DAY"
SAVED_TIME_1WEEK="$SAVED_TIME_1WEEK"

# Disk usage variables (updated every 10 seconds)
BOOT_DISKFREE_HR="$BOOT_DISKFREE_HR"
BOOT_DISKFREE_KB="$BOOT_DISKFREE_KB"
BOOT_DISKUSED_HR="$BOOT_DISKUSED_HR"
BOOT_DISKUSED_KB="$BOOT_DISKUSED_KB"
BOOT_DISKUSED_PERC="$BOOT_DISKUSED_PERC"
KIIRO_DATA_DISKFREE_HR="$KIIRO_DATA_DISKFREE_HR"
KIIRO_DATA_DISKFREE_KB="$KIIRO_DATA_DISKFREE_KB"
KIIRO_DATA_DISKUSED_HR="$KIIRO_DATA_DISKUSED_HR"
KIIRO_DATA_DISKUSED_KB="$KIIRO_DATA_DISKUSED_KB"
KIIRO_DATA_DISKUSED_PERC="$KIIRO_DATA_DISKUSED_PERC"

# IP addresses (only rechecked once every 15 minutes)
IP4_EXTERNAL="$IP4_EXTERNAL"

# Store Kiirocoin blockchain sync progress
KIIRO_BLOCKSYNC_VALUE="$KIIRO_BLOCKSYNC_VALUE"
EOF

}

# Function to gather CPU stats in the background
get_cpu_stats() {
    while true; do
        stats=$(mpstat -P ALL 1 1 | awk '/Average:/ && $2 ~ /[0-9]/ {print $2, 100-$NF}')

        num_cores=$(echo "$stats" | wc -l)
        split_point=$(((num_cores + 1) / 2))

        cpu_usage_1=""
        cpu_usage_2=""
        total_usage=0
        counter=1

        while IFS= read -r line; do
            core=$(echo "$line" | awk '{print $1}')
            usage=$(echo "$line" | awk '{printf "%.1f", $2}')

            total_usage=$(echo "$total_usage + $usage" | bc)

            if [ "$counter" -le "$split_point" ]; then
                cpu_usage_1+="#${core}: ${usage}%    "
            else
                cpu_usage_2+="#${core}: ${usage}%    "
            fi

            counter=$((counter + 1))
        done <<<"$stats"

        average_usage=$(echo "scale=1; $total_usage / $num_cores" | bc)

        echo "$cpu_usage_1" >"$cpu1_file"
        echo "$cpu_usage_2" >"$cpu2_file"
        echo "$average_usage" >"$avg_file"
        sleep 0.95
    done
}

pre_loop() {

    printf " =============== Performing Startup Checks ==============================\\n\\n"
    # ===============================================================================

    # Setup loopcounter - used for debugging
    loopcounter=0

    # Set timenow variable with the current time
    TIME_NOW=$(date)
    TIME_NOW_UNIX=$(date +%s)

    # Check timers in case they have been tampered with, and repair if necessary

    if [ "$SAVED_TIME_10SEC" = "" ]; then
        str="Repairing 10 Second timer..."
        printf "%b %s" "${INFO}" "${str}"
        # set 10 sec timer and save to settings file
        SAVED_TIME_10SEC="$(date +%s)"
        sed -i -e "/^SAVED_TIME_10SEC=/s|.*|SAVED_TIME_10SEC=\"$(date +%s)\"|" $KIIRO_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    if [ "$SAVED_TIME_1MIN" = "" ]; then
        str="Repairing 1 Minute timer..."
        printf "%b %s" "${INFO}" "${str}"
        # set 1 min timer and save to settings file
        SAVED_TIME_1MIN="$(date +%s)"
        sed -i -e "/^SAVED_TIME_1MIN=/s|.*|SAVED_TIME_1MIN=\"$(date +%s)\"|" $KIIRO_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    if [ "$SAVED_TIME_15MIN" = "" ]; then
        str="Repairing 15 Minute timer..."
        printf "%b %s" "${INFO}" "${str}"
        # set 15 min timer and save to settings file
        SAVED_TIME_15MIN="$(date +%s)"
        sed -i -e "/^SAVED_TIME_15MIN=/s|.*|SAVED_TIME_15MIN=\"$(date +%s)\"|" $KIIRO_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    if [ "$SAVED_TIME_1DAY" = "" ]; then
        str="Repairing 1 Day timer..."
        printf "%b %s" "${INFO}" "${str}"
        # set 15 min timer and save to settings file
        SAVED_TIME_1DAY="$(date +%s)"
        sed -i -e "/^SAVED_TIME_1DAY=/s|.*|SAVED_TIME_1DAY=\"$(date +%s)\"|" $KIIRO_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    if [ "$SAVED_TIME_1WEEK" = "" ]; then
        str="Repairing 1 Week timer..."
        printf "%b %s" "${INFO}" "${str}"
        # set 1 week timer and save to settings file
        SAVED_TIME_1WEEK="$(date +%s)"
        sed -i -e "/^SAVED_TIME_1WEEK=/s|.*|SAVED_TIME_1WEEK=\"$(date +%s)\"|" $KIIRO_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # update external IP address and save to settings file
    if [ "$IP4_EXTERNAL" = "" ]; then
        str="Looking up IP4 external address..."
        printf "%b %s" "${INFO}" "${str}"
        IP4_EXTERNAL_QUERY=$(dig @resolver4.opendns.com myip.opendns.com +short 2>/dev/null)
        if [ $IP4_EXTERNAL_QUERY != "" ]; then
            IP4_EXTERNAL=$IP4_EXTERNAL_QUERY
            sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"$IP4_EXTERNAL\"|" $KIIRO_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            IP4_EXTERNAL="OFFLINE"
            sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"OFFLINE\"|" $KIIRO_SETTINGS_FILE
            printf "%b%b %s Offline!\\n" "${OVER}" "${CROSS}" "${str}"
        fi
    fi

    printf "\\n"

    # Check the current version of Kiirocoin Core, as well as the release type, if we don't already know them

    if [ "$KIIRO_STATUS" = "running" ]; then
        printf "%b Checking Kiirocoin Core...\\n" "${INFO}"
    fi

    # Is Kiirocoin Node starting up?
    if [ "$KIIRO_STATUS" = "running" ]; then
        KIIRO_BLOCKCOUNT_LOCAL_QUERY=$($KIIRO_CLI getblockcount 2>/dev/null)
        if [ "$KIIRO_BLOCKCOUNT_LOCAL_QUERY" = "" ]; then
            KIIRO_STATUS="startingup"
        else
            KIIRO_BLOCKCOUNT_LOCAL=$KIIRO_BLOCKCOUNT_LOCAL_QUERY
            KIIRO_BLOCKCOUNT_FORMATTED=$(printf "%'d" $KIIRO_BLOCKCOUNT_LOCAL)

            # Query current version number of Kiirocoin Core
            KIIRO_VER_LOCAL_QUERY=$($KIIRO_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
            if [ "$KIIRO_VER_LOCAL_QUERY" != "" ] && [ "$KIIRO_PRERELEASE" = "NO" ]; then
                KIIRO_VER_LOCAL=$KIIRO_VER_LOCAL_QUERY
                sed -i -e "/^KIIRO_VER_LOCAL=/s|.*|KIIRO_VER_LOCAL=\"$KIIRO_VER_LOCAL\"|" $KIIRO_SETTINGS_FILE
            fi
        fi
    fi

    # Check if Kiirocoin Node is successfully responding to requests yet while starting up. If not, get the current error.
    if [ "$KIIRO_STATUS" = "startingup" ]; then
        # Query if kiirobyte has finished starting up. Display error. Send success to null.
        is_kiiro_live_query=$($KIIRO_CLI getinfo 2>&1 1>/dev/null)
        if [ "$is_kiiro_live_query" != "" ]; then
            KIIRO_ERROR_MSG=$(echo $is_kiiro_live_query | cut -d ':' -f3)
        else
            KIIRO_STATUS="running"
        fi
    fi

    # Is Kiirocoin Node running?
    if [ "$KIIRO_STATUS" = "running" ]; then
        # Get masternoade status
        EVO_JSON=$($KIIRO_CLI evoznode status 2>/dev/null)
        KIIRO_EVO_STATUS=$(echo $EVO_JSON | jq -r .status)

        # Get masternoade state
        KIIRO_EVO_STATE=$(echo $EVO_JSON | jq -r .state)

        if [ "$KIIRO_EVO_STATE" = "READY" ] || [ "$KIIRO_EVO_STATE" = "POSE_BANNED" ]; then
            KIIRO_EVO_PROTXHASH=$(echo $EVO_JSON | jq -r .proTxHash)
            KIIRO_EVO_COLLATERALAMOUNT=$(echo $EVO_JSON | jq -r .collateralAmount)
            KIIRO_EVO_NEEDTOUPGRADE=$(echo $EVO_JSON | jq -r .needToUpgrade)
            KIIRO_EVO_LASTPAIDHEIGHT=$(echo $EVO_JSON | jq -r .dmnState.lastPaidHeight)
            KIIRO_EVO_POSEBANHEIGHT=$(echo $EVO_JSON | jq -r .dmnState.PoSeBanHeight)
        fi
    fi

    printf "\\n"

    str="Starting background process for CPU stats..."
    printf "%b %s" "${INFO}" "${str}"

    # Get number of CPU cores
    cpu_cores=$(nproc)

    # Paths for temporary files to store CPU usage values
    cpu1_file=$(mktemp)
    cpu2_file=$(mktemp)
    avg_file=$(mktemp)

    # Start the get_cpu_stats function in the background
    get_cpu_stats &

    bg_cpu_stats_pid=$!

    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Enable displaying startup messaging for first loop
    STARTUP_LOOP=true

    # Declare the associative array to store the table variables
    declare -A global_variables_table

    # Get the current terminal width
    term_width=$(tput cols)

}
# Run checks to be sure that kiirocoin node is installed and running
is_kiironode_installed() {

    # Set local variables for Kiirocoin Core checks
    local find_kiiro_folder
    local find_kiiro_binaries
    local find_kiiro_data_folder
    local find_kiiro_conf_file
    local find_kiiro_service

    # Begin check to see that Kiirocoin Core is installed
    printf "%b Looking for Kiirocoin Core...\\n" "${INFO}"
    printf "\\n"

    # Check for kiirocoin core install folder in home folder (either 'kiirocoin' folder itself, or a symbolic link pointing to it)
    if [ -h "$KIIRO_INSTALL_LOCATION" ]; then
        find_kiiro_folder="yes"
        is_kiiro_installed="maybe"
    else
        if [ -e "$KIIRO_INSTALL_LOCATION" ]; then
            find_kiiro_folder="yes"
            is_kiiro_installed="maybe"
        else
            printf "\\n"
            printf "%b %bERROR: Unable to detect Kiirocoin Node install folder%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b This script is unable to detect your Kiirocoin Core installation folder\\n" "${INDENT}"
            if [ "$LOCATE_KIIROCOIN" = true ]; then
                is_kiiro_installed="no"
                locate_kiirocoin_node
            else
                printf "\\n"
                is_kiiro_installed="no"
            fi
        fi
    fi

    # Check if kiirocoind is installed
    if [ -f "$KIIRO_DAEMON" -a -f "$KIIRO_CLI" ]; then
        find_kiiro_binaries="yes"
        is_kiiro_installed="yes"
        KIIRO_CURRENT_VERSION=$($KIIRO_CLI -version 2>/dev/null | cut -d ' ' -f6 | cut -d '-' -f1)
    else
        printf "%b %bERROR: Unable to locate Kiirocoin Core binaries.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b This script is unable to find your Kiirocoin Core binaries - kiirocoind & kiirocoin-cli.\\n" "${INDENT}"
        if [ "$LOCATE_KIIROCOIN" = true ] && [ "$SKIP_DETECTING_KIIROCOIN" != "YES" ]; then
            is_kiiro_installed="no"
            locate_kiirocoin_node
        else
            printf "\\n"
            is_kiiro_installed="no"
        fi
    fi

    # Check if kiirocoin core is configured to run as a service
    if [ -f "$KIIRO_SYSTEMD_SERVICE_FILE" ]; then
        find_kiiro_service="yes"
    else
        printf "%b %bWARNING: kiirocoind.service not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b To ensure your Kiirocoin Node stays running 24/7, it is a good idea to setup\\n" "${INDENT}"
        printf "%b Kiirocoin daemon to run as a service. If you already have a systemd service file\\n" "${INDENT}"
        printf "%b to run 'kiirocoind', you can rename it to /etc/systemd/system/kiirocoind.service\\n" "${INDENT}"
        printf "%b so that this script can find it. If you wish to setup your Kiirocoin Node to run\\n" "${INDENT}"
        printf "%b as a service, you can use KiiroNode Setup.\\n" "${INDENT}"
        printf "\\n"
        local kiiro_service_warning="yes"
    fi

    # Check for .kiirocoin data directory
    if [ -d "$KIIRO_SETTINGS_LOCATION" ]; then
        find_kiiro_settings_folder="yes"
    else
        printf "%b %bERROR: ~/.kiirocoin settings folder not found.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b The Kiirocoin settings folder contains your wallet and kiirocoin.conf\\n" "${INDENT}"
        printf "%b in addition to the blockchain data itself. The folder was not found in\\n" "${INDENT}"
        printf "%b the expected location here: $KIIRO_DATA_LOCATION\\n" "${INDENT}"
        printf "\\n"
    fi

    # Check kiirocoin.conf file can be found
    if [ -f "$KIIRO_CONF_FILE" ]; then
        find_kiiro_conf_file="yes"
        printf "%b kiirocoin.conf file located.\\n" "${TICK}"
        scrape_kiirocoin_conf
    else
        printf "%b %bERROR: kiirocoin.conf not found.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b The kiirocoin.conf contains important configuration settings for\\n" "${INDENT}"
        printf "%b your node. KiiroNode Setup can help you create one.\\n" "${INDENT}"
        printf "%b The expected location is here: $KIIRO_CONF_FILE\\n" "${INDENT}"
        printf "\\n"
        if [ "$is_kiiro_installed" = "yes" ]; then
            exit 1
        fi
    fi

    # If kiirocoind service is failing, then display the error
    if [ $(systemctl is-active kiirocoind) = 'failed' ] && [ "$is_kiiro_installed" = "yes" ]; then
        local known_kiiro_service_error
        known_kiiro_service_error="no"

        if [ $known_kiiro_service_error = "no" ]; then
            printf "\\n"
            printf "%b %bERROR: kiirocoind service does not appear to be running.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            KIIRO_STATUS="stopped"
        fi
    fi

    str="Checking Kiirocoin Node chain..."
    printf "%b %s" "${INFO}" "${str}"

    # Query if Kiirocoin Core is running the mainn, test, regtest ro signet chain
    query_kiirocoin_chain
    printf "%b%b %s MAINNET (live)\\n" "${OVER}" "${TICK}" "${str}"

    # Get current listening port
    kiirocoin_port_query

    # Show current listening port of Kiirocoin Node
    if [ "$KIIRO_LISTEN_PORT" != "" ] && [ "$KIIRO_LISTEN_PORT_LIVE" = "YES" ]; then
        printf "%b Kiirocoin Node listening port: $KIIRO_LISTEN_PORT (live)\\n" "${INFO}"
    elif [ "$KIIRO_LISTEN_PORT" != "" ] && [ "$KIIRO_LISTEN_PORT_LIVE" = "NO" ]; then
        printf "%b Kiirocoin Node listening port: $KIIRO_LISTEN_PORT (from kiirocoin.conf)\\n" "${INFO}"
    fi

    # Run checks to see Kiirocoin Core is running
    # Check if kiirocoin daemon is running as a service.
    if [ $(systemctl is-active kiirocoind) = 'active' ]; then
        KIIRO_STATUS="running"
    else
        # Check if kiirocoind is running (but not as a service).
        if [ "" != "$(pgrep kiirocoind)" ] && [ "$KIIRO_DUAL_NODE" = "NO" ]; then
            KIIRO_STATUS="running"
        else
            KIIRO_STATUS="stopped"
        fi
    fi

    # Display message if the Kiirocoin Node is running okay
    if [ "$find_kiiro_folder" = "yes" ] && [ "$find_kiiro_binaries" = "yes" ] && [ "$find_kiiro_settings_folder" = "yes" ] && [ "$find_kiiro_conf_file" = "yes" ] && [ "$KIIRO_STATUS" = "running" ]; then
        printf "%b %bKiirocoin Node Status: RUNNING%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    elif [ "$find_kiiro_folder" = "yes" ] && [ "$find_kiiro_binaries" = "yes" ] && [ "$find_kiiro_settings_folder" = "yes" ] && [ "$find_kiiro_conf_file" = "yes" ]; then
        printf "%b %bKiirocoin Node Status: STOPPED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        KIIRO_STATUS="stopped"
    fi

    if [ "$is_kiiro_installed" = "no" ]; then
        printf "%b %bKiirocoin Node Status: NOT DETECTED%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        KIIRO_STATUS="not_detected"
    fi

    printf "\\n"

}

firstrun_monitor_configs() {
    # If this is the first time running the Dashboard, set the variables that update periodically
    if [ "$KIIRO_MONITOR_FIRST_RUN" = "" ]; then

        printf "%b First time running KiiroNode Dashboard. Performing initial setup...\\n" "${INFO}"

        # Log date of Dashboard first run to kiironode.settings
        str="Logging date of first run to kiironode.settings file..."
        printf "  %b %s" "${INFO}" "${str}"
        KIIRO_MONITOR_FIRST_RUN=$(date)
        sed -i -e "/^KIIRO_MONITOR_FIRST_RUN=/s|.*|KIIRO_MONITOR_FIRST_RUN=\"$KIIRO_MONITOR_FIRST_RUN\"|" $KIIRO_SETTINGS_FILE
        printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        printf "\\n"
    fi
}

display_dashboard() {
    banner
    display_help
    printf "%b Checking for / installing required dependencies for KiiroNode Setup...\\n" "${INFO}"
    install_dependent_packages "${SETUP_DEPS[@]}"
    set_sys_variables           # Set various system variables once we know we are on linux
    kiironode_import_settings   # Create kiironode.settings file (if it does not exist)
    kiironode_create_settings   # Create kiiroinode.settings file (if it does not exist)
    is_kiironode_installed      # Run checks to see if Kiirocoin Node is present. Exit if it isn't. Import kiirocoin.conf.
    check_kiiro_rpc_credentials # Check the RPC username and password from kiirocoin.conf file. Warn if not present.
    firstrun_monitor_configs    # Do some configuration if this is the first time running the KiiroNode Dashboard
    pre_loop
    EXIT_DASHBOARD=false
    while :; do
        # Quit Dashboard automatically based on the time set in kiironode.settings
        # Dashboard will run indefinitely if the value is set to 0

        # First convert SM_AUTO_QUIT from minutes into seconds
        if [ $SM_AUTO_QUIT -gt 0 ]; then
            auto_quit_seconds=$(( $SM_AUTO_QUIT*60 ))
            auto_quit_half_seconds=$(( $auto_quit_seconds*2 ))
            if [ $loopcounter -gt $auto_quit_half_seconds ]; then
                auto_quit=true
                EXIT_DASHBOARD=true
            fi
        fi

        # First convert SM_AUTO_QUIT from minutes into seconds

        if [ "$STARTUP_LOOP" = true ]; then
            printf "%b Updating Status: 1 Second Loop...\\n" "${INFO}"
        fi

        # ------------------------------------------------------------------------------
        #    UPDATE EVERY 1 SECOND - HARDWARE
        # ------------------------------------------------------------------------------

        # Update timenow variable with current time
        TIME_NOW=$(date)
        TIME_NOW_UNIX=$(date +%s)
        loopcounter=$((loopcounter + 1))

        # Get current memory usage
        RAMUSED_HR=$(free --mega -h | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f3)
        RAMAVAIL_HR=$(free --mega -h | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f6)
        SWAPUSED_HR=$(free --mega -h | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f3)
        SWAPAVAIL_HR=$(free --mega -h | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f4)

        # ------------------------------------------------------------------------------
        #    UPDATE EVERY 1 SECOND - CPU USAGE
        # ------------------------------------------------------------------------------

        # This all runs as a background process now. See get_cpu_stats function

        # ------------------------------------------------------------------------------
        #    UPDATE EVERY 1 SECOND - KIIROCOIN NODE
        # ------------------------------------------------------------------------------

        # Check if Kiirocoin Node is actually installed
        if [ $KIIRO_STATUS != "not_detected" ]; then

            # Is kiirocoind running as a service?
            systemctl is-active --quiet kiirocoind && KIIRO_STATUS="running" || KIIRO_STATUS="checkagain"

            # If it is not running as a service, check if kiirocoind is running via the command line
            if [ "$KIIRO_STATUS" = "checkagain" ] && [ "$KIIRO_DUAL_NODE" = "NO" ]; then
                if [ "" != "$(pgrep kiirocoind)" ]; then
                    KIIRO_STATUS="running"
                fi
            fi

            # If kiirocoind is not running via the command line, check if kiirocoin-qt is running
            if [ "$KIIRO_STATUS" = "checkagain" ] && [ "$KIIRO_DUAL_NODE" = "NO" ]; then
                if [ "" != "$(pgrep kiirocoin-qt)" ]; then
                    KIIRO_STATUS="running"
                fi
            fi

            if [ "$KIIRO_STATUS" = "checkagain" ]; then
                KIIRO_STATUS="stopped"
                KIIRO_BLOCKSYNC_PROGRESS=""
                KIIRO_ERROR_MSG=""
                RPC_PORT=""
            fi

            # If we think the blockchain is running, check the blockcount
            if [ "$KIIRO_STATUS" = "running" ]; then

                # If the blockchain is not yet synced, get blockcount
                if [ "$KIIRO_BLOCKSYNC_PROGRESS" = "" ] || [ "$KIIRO_BLOCKSYNC_PROGRESS" = "notsynced" ]; then
                    KIIRO_BLOCKCOUNT_LOCAL=$($KIIRO_CLI getblockcount 2>/dev/null)
                    KIIRO_BLOCKCOUNT_FORMATTED=$(printf "%'d" $KIIRO_BLOCKCOUNT_LOCAL)

                    # If we don't get a response, assume it is starting up
                    if [ "$KIIRO_BLOCKCOUNT_LOCAL" = "" ]; then
                        KIIRO_STATUS="startingup"
                        # Get updated kiirocoin.conf
                        scrape_kiirocoin_conf
                        # query for kiirocoin network
                        query_kiirocoin_chain
                        # query for kiirocoin listening port
                        kiirocoin_port_query
                        # update rpc credentials
                        kiirocoin_rpc_query
                        KIIRO_TROUBLESHOOTING_MSG="1sec: running>startingup"
                    fi
                fi
            fi

        fi

        # THE REST OF THIS ONLY RUNS NOTE IF KIIROCOIN NODE IS RUNNING
        if [ "$KIIRO_STATUS" = "running" ]; then
            # This will update the blockchain sync progress every second until it is fully synced
            if [ "$KIIRO_BLOCKSYNC_PROGRESS" = "notsynced" ] || [ "$KIIRO_BLOCKSYNC_PROGRESS" = "" ]; then
                KIIRO_BLOCKSYNC_VALUE_QUERY=$(tail -n 10 $KIIRO_SETTINGS_LOCATION/debug.log | grep 'UpdateTip:' | cut -d' ' -f12 | cut -d'=' -f2)
                # Is the returned value numerical?
                re='^[0-9]+([.][0-9]+)?$'
                if ! [[ $KIIRO_BLOCKSYNC_VALUE_QUERY =~ $re ]]; then
                    KIIRO_BLOCKSYNC_VALUE_QUERY=""
                fi
                # Only update the variable, if a new value is found
                if [ "$KIIRO_BLOCKSYNC_VALUE_QUERY" != "" ]; then
                    KIIRO_BLOCKSYNC_VALUE=$KIIRO_BLOCKSYNC_VALUE_QUERY
                    sed -i -e "/^KIIRO_BLOCKSYNC_VALUE=/s|.*|KIIRO_BLOCKSYNC_VALUE=\"$KIIRO_BLOCKSYNC_VALUE\"|" $KIIRO_SETTINGS_FILE
                fi
                # Calculate blockchain sync percentage
                if [ "$KIIRO_BLOCKSYNC_VALUE" = "" ] || [ "$KIIRO_BLOCKSYNC_VALUE" = "0" ]; then
                    KIIRO_BLOCKSYNC_PERC="0.00"
                else
                    KIIRO_BLOCKSYNC_PERC=$(echo "scale=2 ;$KIIRO_BLOCKSYNC_VALUE*100" | bc)
                fi
                # Round blockchain sync percentage to two decimal places
                KIIRO_BLOCKSYNC_PERC=$(printf "%.2f \n" $KIIRO_BLOCKSYNC_PERC)
                # Detect if the blockchain is fully synced
                if [ "$KIIRO_BLOCKSYNC_PERC" = "100.00 " ]; then
                    KIIRO_BLOCKSYNC_PERC="100 "
                    KIIRO_BLOCKSYNC_PROGRESS="synced"
                fi

            fi

            # Show port warning if connections are less than or equal to 7
            KIIRO_CONNECTIONS=$($KIIRO_CLI getconnectioncount 2>/dev/null)
            KIIRO_CONNECTED_PEERS_NEW=$($KIIRO_CLI getpeerinfo 2>/dev/null | jq -r .[].subver  | grep "1.0.0.4" | wc -l)
            KIIRO_CONNECTED_PEERS_OLD=$($KIIRO_CLI getpeerinfo 2>/dev/null | jq -r .[].subver  | grep -v "1.0.0.4" | wc -l)
            if [ $KIIRO_CONNECTIONS -le 8 ]; then
                KIIRO_CONNECTIONS_MSG="${txtred}Warning: Low Connections!${txtrst}"
            fi
            if [ $KIIRO_CONNECTIONS -ge 9 ]; then
                KIIRO_CONNECTIONS_MSG="Maximum: $KIIRO_MAX_CONNECTIONS"
            fi

            # Get primary kiirocoind Node Uptime
            #kiiro_uptime_seconds=$($KIIRO_CLI uptime 2>/dev/null)
            #kiiro_uptime=$(eval "echo $(date -ud "@$kiiro_uptime_seconds" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')")

            # Calculate when it was first online
            #current_time=$(date +"%s")
            #kiiro_start_time=$((current_time - kiiro_uptime_seconds))
            #kiiro_online_since=$(date -d "@$kiiro_start_time" +"%H:%M %d %b %Y %Z")

        fi

        # ------------------------------------------------------------------------------
        #    Run once every 10 seconds
        #    Every 10 seconds lookup the latest block from the online block exlorer to calculate sync progress.
        # ------------------------------------------------------------------------------
        TIME_DIF_10SEC=$(($TIME_NOW_UNIX - $SAVED_TIME_10SEC))

        if [ $TIME_DIF_10SEC -ge 10 ]; then

            if [ "$STARTUP_LOOP" = true ]; then
                printf "%b Updating Status: 10 Second Loop...\\n" "${INFO}"
            fi

            # KIIROCOIN NODE ---->

            # Check if Kiirocoin Node is successfully responding to requests yet while starting up. If not, get the current error.
            if [ "$KIIRO_STATUS" = "startingup" ]; then

                # Refresh kiironode.settings to get the latest value of KIIRO_VER_LOCAL
                source $KIIRO_SETTINGS_FILE
            fi

            # Update local block count every 10 seconds (approx once per block)
            # Is kiirocoind in the process of starting up, and not ready to respond to requests?
            if [ "$KIIRO_STATUS" = "running" ] && [ "$KIIRO_BLOCKSYNC_PROGRESS" = "synced" ]; then
                KIIRO_BLOCKCOUNT_LOCAL=$($KIIRO_CLI getblockcount 2>/dev/null)
                KIIRO_BLOCKCOUNT_FORMATTED=$(printf "%'d" $KIIRO_BLOCKCOUNT_LOCAL)
                if [ "$KIIRO_BLOCKCOUNT_LOCAL" = "" ]; then
                    KIIRO_STATUS="startingup"
                    KIIRO_LISTEN_PORT=""
                    # Get updated kiirocoin.conf
                    scrape_kiirocoin_conf
                    # query for kiirocoin network
                    query_kiirocoin_chain
                    # query for kiirocoin listening port
                    kiirocoin_port_query
                    # update rpc credentials
                    kiirocoin_rpc_query
                    KIIRO_TROUBLESHOOTING_MSG="10sec: running > startingup"
                fi
            fi

            # update external IP if it is offline
            if [ "$IP4_EXTERNAL" = "OFFLINE" ]; then

                # Check if the KiiroNode has gone offline
                wget -q --connect-timeout=0.5 --spider http://google.com
                if [ $? -eq 0 ]; then
                    IP4_EXTERNAL_QUERY=$(dig @resolver4.opendns.com myip.opendns.com +short 2>/dev/null)
                    if [ $IP4_EXTERNAL_QUERY != "" ]; then
                        IP4_EXTERNAL=$IP4_EXTERNAL_QUERY
                        sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"$IP4_EXTERNAL\"|" $KIIRO_SETTINGS_FILE
                    fi
                fi

            fi

            # Lookup disk usage, and store in kiironode.settings if present
            update_disk_usage

            SAVED_TIME_10SEC="$(date +%s)"
            sed -i -e "/^SAVED_TIME_10SEC=/s|.*|SAVED_TIME_10SEC=\"$(date +%s)\"|" $KIIRO_SETTINGS_FILE
        fi

        # ------------------------------------------------------------------------------
        #    Run once every 1 minute
        #    Every minute lookup the latest block from the online block exlorer to calculate sync progress.
        # ------------------------------------------------------------------------------

        TIME_DIF_1MIN=$(($TIME_NOW_UNIX - $SAVED_TIME_1MIN))

        if [ $TIME_DIF_1MIN -ge 60 ]; then

            if [ "$STARTUP_LOOP" = true ]; then
                printf "%b Updating Status: 1 Minute Loop...\\n" "${INFO}"
            fi

            # KIIROCOIN NODE ---->

            # Update Kiirocoin Node sync progress every minute, if it is running
            if [ "$KIIRO_STATUS" = "running" ]; then

                # Get masternoade status
                EVO_JSON=$($KIIRO_CLI evoznode status 2>/dev/null)
                KIIRO_EVO_STATUS=$(echo $EVO_JSON | jq -r .status)

                # Get masternoade state
                KIIRO_EVO_STATE=$(echo $EVO_JSON | jq -r .state)

                if [ "$KIIRO_EVO_STATE" = "READY" ] || [ "$KIIRO_EVO_STATE" = "POSE_BANNED" ]; then
                    KIIRO_EVO_PROTXHASH=$(echo $EVO_JSON | jq -r .proTxHash)
                    KIIRO_EVO_COLLATERALAMOUNT=$(echo $EVO_JSON | jq -r .collateralAmount)
                    KIIRO_EVO_NEEDTOUPGRADE=$(echo $EVO_JSON | jq -r .needToUpgrade)
                    KIIRO_EVO_LASTPAIDHEIGHT=$(echo $EVO_JSON | jq -r .dmnState.lastPaidHeight)
                    KIIRO_EVO_POSEBANHEIGHT=$(echo $EVO_JSON | jq -r .dmnState.PoSeBanHeight)
                fi

                # Get current listening port
                KIIRO_LISTEN_PORT=$($KIIRO_CLI getnetworkinfo 2>/dev/null | jq .localaddresses[0].port)

                # Lookup sync progress value from debug.log. Use previous saved value if no value is found.
                if [ "$KIIRO_BLOCKSYNC_PROGRESS" = "synced" ]; then

                    # Lookup the sync progress value from debug.log
                    KIIRO_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $KIIRO_SETTINGS_LOCATION/debug.log | cut -d' ' -f12 | cut -d'=' -f2)

                    # Is the returned value numerical?
                    re='^[0-9]+([.][0-9]+)?$'
                    if ! [[ $KIIRO_BLOCKSYNC_VALUE_QUERY =~ $re ]]; then
                        KIIRO_BLOCKSYNC_VALUE_QUERY=""
                    fi

                    # Ok, we got a number back. Update the variable.
                    if [ "$KIIRO_BLOCKSYNC_VALUE_QUERY" != "" ]; then
                        KIIRO_BLOCKSYNC_VALUE=$KIIRO_BLOCKSYNC_VALUE_QUERY
                        sed -i -e "/^KIIRO_BLOCKSYNC_VALUE=/s|.*|KIIRO_BLOCKSYNC_VALUE=\"$KIIRO_BLOCKSYNC_VALUE\"|" $KIIRO_SETTINGS_FILE
                    fi

                    # Calculate blockchain sync percentage
                    KIIRO_BLOCKSYNC_PERC=$(echo "scale=2 ;$KIIRO_BLOCKSYNC_VALUE*100" | bc)

                    # Round blockchain sync percentage to two decimal places
                    KIIRO_BLOCKSYNC_PERC=$(printf "%.2f \n" $KIIRO_BLOCKSYNC_PERC)

                    # If it's at 100.00, get rid of the decimal zeros
                    if [ "$KIIRO_BLOCKSYNC_PERC" = "100.00 " ]; then
                        KIIRO_BLOCKSYNC_PERC="100 "
                    fi

                    # Check if sync progress is not 100%
                    if [ "$KIIRO_BLOCKSYNC_PERC" = "100 " ]; then
                        KIIRO_BLOCKSYNC_PROGRESS="synced"
                    else
                        KIIRO_BLOCKSYNC_PROGRESS="notsynced"
                        WALLET_BALANCE=""
                    fi
                fi
            fi

            # Check if the KiiroNode has gone offline
            wget -q --connect-timeout=0.5 --spider http://google.com
            if [ $? -ne 0 ]; then
                IP4_EXTERNAL="OFFLINE"
                sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"OFFLINE\"|" $KIIRO_SETTINGS_FILE
            fi

            # Update kiironode.settings with when Dashboard last ran
            KIIRO_MONITOR_LAST_RUN=$(date)
            sed -i -e "/^KIIRO_MONITOR_LAST_RUN=/s|.*|KIIRO_MONITOR_LAST_RUN=\"$(date)\"|" $KIIRO_SETTINGS_FILE

            SAVED_TIME_1MIN="$(date +%s)"
            sed -i -e "/^SAVED_TIME_1MIN=/s|.*|SAVED_TIME_1MIN=\"$(date +%s)\"|" $KIIRO_SETTINGS_FILE

        fi

        # ------------------------------------------------------------------------------
        #    Run once every 15 minutes
        #    Update the Internal & External IP
        # ------------------------------------------------------------------------------

        TIME_DIF_15MIN=$(($TIME_NOW_UNIX - $SAVED_TIME_15MIN))

        if [ $TIME_DIF_15MIN -ge 900 ]; then

            if [ "$STARTUP_LOOP" = true ]; then
                printf "%b Updating Status: 15 Minute Loop...\\n" "${INFO}"
            fi

            # update external IP, unless it is offline
            if [ "$IP4_EXTERNAL" != "OFFLINE" ]; then

                IP4_EXTERNAL_QUERY=$(dig @resolver4.opendns.com myip.opendns.com +short +timeout=5 2>/dev/null)
                if [ "$IP4_EXTERNAL_QUERY" != "" ]; then
                    IP4_EXTERNAL=$IP4_EXTERNAL_QUERY
                    sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"$IP4_EXTERNAL\"|" $KIIRO_SETTINGS_FILE
                else
                    IP4_EXTERNAL="OFFLINE"
                    sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"OFFLINE\"|" $KIIRO_SETTINGS_FILE
                fi
            fi

            SAVED_TIME_15MIN="$(date +%s)"
            sed -i -e "/^SAVED_TIME_15MIN=/s|.*|SAVED_TIME_15MIN=\"$(date +%s)\"|" $KIIRO_SETTINGS_FILE
        fi

        # ------------------------------------------------------------------------------
        #    Run once every 24 hours
        #    Check for new version of Kiirocoin Core
        # ------------------------------------------------------------------------------

        TIME_DIF_1DAY=$(($TIME_NOW_UNIX - $SAVED_TIME_1DAY))

        if [ $TIME_DIF_1DAY -ge 86400 ]; then

            if [ "$STARTUP_LOOP" = true ]; then
                printf "%b Updating Status: 24 Hour Loop...\\n" "${INFO}"
            fi

            # reset 24 hour timer
            SAVED_TIME_1DAY="$(date +%s)"
            sed -i -e "/^SAVED_TIME_1DAY=/s|.*|SAVED_TIME_1DAY=\"$(date +%s)\"|" $KIIRO_SETTINGS_FILE
        fi

        if [ "$STARTUP_LOOP" = true ]; then
            printf "%b Generating dashboard...\\n" "${INFO}"
        fi

        ###################################################################
        #### GENERATE DISPLAY OUTPUT ######################################
        ###################################################################

        # Store the previous terminal width (in case it has been resized since the previous loop)
        term_width_previous=$term_width

        # Get the width of the terminal
        term_width=$(tput cols)

        # Has the table been rezized since previous loop?
        if [ "$term_width" != "$term_width_previous" ]; then
            terminal_resized="yes"
        else
            terminal_resized="no"
        fi

        ###################################################################
        # DISPLAY REGENERATING SCREEN WHEN THE TERMINAL WIDTH HAS CHANGED #
        ###################################################################

        if [ "$terminal_resized" = "yes" ] && [ "$STARTUP_LOOP" = false ]; then

            # Define the strings with line breaks
            string1="        Tip: If you find the dashboard suddenly gets duplicated down the\n             screen, you can fix this by scrolling to the bottom of the\n             window. This is caused by a limitation of the terminal.\n"
            string2="           Tip: To launch a website URL from the terminal,\n                use Cmd-click (Mac) or Ctrl-click (Windows)."
            string3="         Tip: To make the dashboard text bigger or smaller, press\n              Ctrl-+ or Ctrl-- (Windows) and Cmd-+ or Cmd-- (MacOS)."

            # Create an array from the individual strings
            strings=("$string1" "$string2" "$string3")

            # Get the current time
            #    current_time=$(date +%s)

            # Check if 60 seconds have passed since the last selection
            #    if ((current_time - last_tip_selection_time >= 500)) || [ "$change_tip" = "yes" ]; then
            if [ "$change_tip" = "yes" ]; then

                # Use shuf to generate a random index
                random_index=$(shuf -i 0-2 -n 1)

                # Use the random index to select a random string from the array
                random_tip="${strings[random_index]}"

                # Update the last tip selection time
                #       last_tip_selection_time=$current_time

                change_tip="no"
            else

                # Display the random string
                printf "$random_tip"

            fi

            # Gernerate out to display when regenerating dashboard after the terminal is resized
            output_regenerating=$(
                printf '\e[2J\e[H'

                echo -e "${txtbld}   _   ___ _           _   _           _         "
                echo -e "  | | / (_|_)         | \ | |         | |        "
                echo -e "  | |/ / _ _ _ __ ___ |  \| | ___   __| | ___    "
                echo -e "  |    \| | | '__/ _ \| . \ |/ _ \ / _  |/ _ \  ${txtrst}┳┓   ┓ ┓        ┓${txtbld}"
                echo -e "  | |\  \ | | | | (_) | |\  | (_) | (_| |  __/  ${txtrst}┃┃┏┓┏┣┓┣┓┏┓┏┓┏┓┏┫${txtbld}"
                echo -e "  \_| \_/_|_|_|  \___/\_| \_/\___/ \__,_|\___|  ${txtrst}┻┛┗┻┛┛┗┗┛┗┛┗┻┛ ┗┻"
                echo ""
                echo ""
                echo ""
                echo "               ╔═══════════════════════════════════════════╗ "
                echo "               ║                                           ║"
                echo "               ║   ${txtbld}Regenerating dashboard. Please wait...${txtrst}  ║"
                echo "               ║                                           ║"
                echo "               ╚═══════════════════════════════════════════╝"
                echo ""
                echo ""
                echo ""
            )

            echo "$output_regenerating"
        fi

        #####################################
        ### GENERATE KIIRONODE DASHBOARD #####
        #####################################

        # Calculate column widths based on terminal width
        col1_width=16
        col2_width=16
        col3_width=$((term_width - col1_width - col2_width - 6)) # 13 is for padding and borders
        col4_width=10

        generate_table_border() {
            # Using printf's repetition functionality to fill space or other characters

            local col1_content col2_content col3_content

            # Determine content for column 1
            if [ "$2" = "═" ]; then
                col1_content=$(printf "%0.s═" $(seq 1 $col1_width))
            else
                col1_content=$(printf "%-*s" $col1_width "$2")
            fi

            # Determine content for column 2
            if [ "$4" = "═" ]; then
                col2_content=$(printf "%0.s═" $(seq 1 $col2_width))
            else
                col2_content=$(printf "%-*s" $col2_width "$4")
            fi

            # Determine content for column 3
            col3_content=$(printf "%0.s$6" $(seq 1 $col3_width))

            # Construct the full row, with a leading space, and print it
            printf " %s%s%s%s%s%s%s\n" "$1" "$col1_content" "$3" "$col2_content" "$5" "$col3_content" "$7"
        }

        # Recalculate the Dashboard layout if the width of the terminal has changed
        if [ "$terminal_resized" = "yes" ] || [ "$STARTUP_LOOP" = true ]; then

            # Generate table border rows
            sm_row_01=$(generate_table_border "╔" "═" "╦" "═" "╦" "═" "╗")
            sm_row_02_mainnet=$(generate_table_border "║" " (MAINNET)" "╠" "═" "╬" "═" "╣")
            sm_row_03=$(generate_table_border "╠" "═" "╬" "═" "╬" "═" "╣")
            sm_row_04=$(generate_table_border "║" " " "╠" "═" "╬" "═" "╣")
            sm_row_05=$(generate_table_border "╚" "═" "╩" "═" "╩" "═" "╝")
            sm_row_06=$(generate_table_border "╔" "═" "╦" "═" "═" "═" "╗")
            sm_row_07=$(generate_table_border "║" "═" "╬" "═" "═" "═" "╣")
            sm_row_08=$(generate_table_border "╚" "═" "╩" "═" "═" "═" "╝")

            # Calculate the column widths based on terminal width
            col_width_kiiro_connections_low=$((term_width - 38 - 29 - 3 - 2))
            col_width_kiiro_connections_max=$((term_width - 38 - 29 - 3 - 2))
            col_width_kiiro_blockheight=$((term_width - 38 - 19 - 3 - 2))
            col_width_kiiro_ports=$((term_width - 38 - 3 - 1))
            col_width_kiiro_ports_long=$((term_width - 38 - 17 - 3 - 3))
            col_width_kiiro_masternode=$((term_width - 38 - 3 - 1))
            col_width_kiiro_masternode_long=$((term_width - 38 - 29 - 3 - 2))
            col_width_kiiro_status=$((term_width - 38 - 3 - 1 + 11))
            col_width_kiiro_version=$((term_width - 38 - 3 - 1))
            col_width_kiiro_version_long=$((term_width - 38 - 3 - 1 + 11))
            col_width_kiiro_startingup=$((term_width - 38 - 14 - 3 - 2 + 11))
            col_width_kiiro_uptime=$((term_width - 38 - 3 - 1)) 
            col_width_kiiro_uptime_long=$((term_width - 38 - 39 - 3 - 2)) 

            col_width_software_wide=$((term_width - 21 - 50 - 2))
            col_width_software=$((term_width - 21 - 35 - 3 + 4))
            col_width_software_narrow=$((term_width - 21 - 27 - 3 - 2 + 8))
            col_width_software_noupdate=$((term_width - 21 - 3 - 1))

            col_width_software_kiiro_wide=$((term_width - 21 - 50 + 1))

            col_width_software_kiiropr_wide=$((term_width - 21 - 50 - 3 + 1))
            col_width_software_kiiropr=$((term_width - 21 - 37 - 3 + 2))
            col_width_software_kiiropr_lessnarrow=$((term_width - 21 - 35 - 3 + 9))
            col_width_software_kiiropr_narrow=$((term_width - 21 - 27 - 3 + 2))

            col_width_software_kiiro_wide=$((term_width - 21 - 50 - 2))
            col_width_software_kiiro=$((term_width - 21 - 37 - 3 + 2))
            col_width_software_kiiro_narrow=$((term_width - 21 - 27 - 3 + 2))

            col_width_software_kubo_wide=$((term_width - 21 - 50 + 6))
            col_width_software_kobo=$((term_width - 21 - 35 - 3 + 4))
            col_width_software_kubo_narrow=$((term_width - 21 - 27 - 3 - 2 + 8))

            col_width_software_node_wide=$((term_width - 21 - 50 + 6))
            col_width_software_node=$((term_width - 21 - 42 - 3 + 9))
            col_width_software_node_narrow=$((term_width - 21 - 35 - 3 + 9))

            col_width_sys_ip4_bothoffline=$((term_width - 17 - 3))
            col_width_sys_ip4_oneoffline=$((term_width - 17 - 3))

            generate_kiiro_lowcon_msg="yes"
            generate_quit_message="yes"
            generate_quit_message_with_porttest="yes"
        fi

        ### GENERATE KIIRONODE DASHBOARD - TABLE ROWS #####

        right_border="  ║ "
        right_border_width=${#right_border}

        # Three/two column row (first two narrow columns are one static string, main content is 3rd.)
        db_content_c1_c2_c3f() {
            local combined_col1_2_text="$1"
            local col3_text="$2"

            # Calculate width for first two columns combined e.g. " ║ KIIROCOIN NODE  ║    CONNECTIONS ║  "
            combined_col1_2_width=${#combined_col1_2_text}

            # Calculate width available for column three content
            col3_width=$((term_width - combined_col1_2_width - right_border_width)) # Width of column 3 fill area

            # Strip ANSI color codes for calculation purposes
            local stripped_col3_text=$(echo -e "$col3_text" | sed 's/\x1b\[[0-9;]*m//g')
            local col3_text_length=${#stripped_col3_text}

            local col3_padding=$((col3_width - col3_text_length))

            # Constructing the row based on the described format
            local full_row
            full_row=$(printf "%-${combined_col1_2_width}s" "${combined_col1_2_text}") # Combined Column 1 and 2 with added space (left-aligned)
            full_row+=$(printf "%b%-${col3_padding}s" "$col3_text")                    # Column 3 content (left-aligned) with spacer
            full_row+=$(printf "$right_border")                                        # The right edge border with spaces

            # Print the row without it wrapping to the next line
            printf "%s\n" "$full_row"

        }

        # Four/three column row (first two columns are one static string, main content is 3rd, 4th column is right-aligned inside square brackets )
        db_content_c1_c2_c3f_c4() {
            local combined_col1_2_text="$1"
            local col3_text="$2"
            local col4_text="[ $3 ]"

            # Calculate width for first two columns combined
            combined_col1_2_width=${#combined_col1_2_text}

            # Strip ANSI color codes for calculation purposes
            local stripped_col3_text=$(echo -e "$col3_text" | sed 's/\x1b\[[0-9;]*m//g')
            local col3_text_length=${#stripped_col3_text}

            local stripped_col4_text=$(echo -e "$col4_text" | sed 's/\x1b\[[0-9;]*m//g')
            local col4_text_length=${#stripped_col4_text}

            # Calculate width available for column three and four content
            local col3_4_width=$((term_width - combined_col1_2_width - right_border_width - col4_text_length))
            local col3_padding=$((col3_4_width - col3_text_length))

            # Constructing the row based on the described format
            local full_row
            full_row=$(printf "%-${combined_col1_2_width}s" "${combined_col1_2_text}") # Combined Column 1 and 2 with added space (left-aligned)
            full_row+=$(printf "%b%-${col3_padding}s" "$col3_text")                    # Column 3 content (left-aligned) with spacer
            full_row+=$(printf "%b%s" "$col4_text" "$right_border")                    # Column 4 and The right edge border with spaces

            # Print the row without it wrapping to the next line
            printf "%s\n" "$full_row"
        }

        # Create finite width chain variables for first column
        kiiro_chain_firstcol="(MAINNET)     "
        kiiro_chain_caps="MAINNET"

        # May sure displayed RPC port only changes when there is a new value
        if [ "$RPC_PORT" != "" ]; then
            kiiro_rpcport_display=$RPC_PORT
        fi

        # Function to center quit message
        center_quit_message() {
            local quit_msg_text="$1"

            # Strip ANSI color codes for calculation purposes
            local stripped_quit_msg=$(echo -e "$quit_msg_text" | sed 's/\x1b\[[0-9;]*m//g')
            local quit_msg_length=${#stripped_quit_msg}

            # Calculate padding required to center text
            local left_padding=$(((term_width - quit_msg_length) / 2))
            local right_padding=$((term_width - left_padding - quit_msg_length))

            # Construct the padded title string using # as the spacer and return it
            printf "%${left_padding}s"
            printf "%b" "$quit_msg_text"
            printf "%${right_padding}s"
        }

        # generate quit message
        if [ "$generate_quit_message" = "yes" ]; then
            quit_message_text="Press ${dbcol_bld}Ctrl-C${dbcol_rst} or ${dbcol_bld}Q${dbcol_rst} to Quit."
            quit_message=$(center_quit_message "$quit_message_text")
            generate_quit_message="no"
        fi

        # FORMAT URL POSITION IN HEADER

        if [ "$STARTUP_LOOP" = true ]; then
            printf "%b Buffering dashboard...\\n" "${INFO}"
        fi

        ###################################################################
        #### BUFFER DIGNODE DASHBOARD #####################################
        ###################################################################

        # Double buffer output to reduce display flickering
        output=$(
            tput cup 0 0

            printf "   _   ___ _           _   _           _         " && tput el && printf "\\n"
            printf "  | | / (_|_)         | \ | |         | |        " && tput el && printf "\\n"
            printf "  | |/ / _ _ _ __ ___ |  \| | ___   __| | ___    " && tput el && printf "\\n"
            printf "  |    \| | | '__/ _ \| . \ |/ _ \ / _  |/ _ \  ${txtrst}┳┓   ┓ ┓        ┓${txtbld}" && tput el && printf "\\n"
            printf "  | |\  \ | | | | (_) | |\  | (_) | (_| |  __/  ${txtrst}┃┃┏┓┏┣┓┣┓┏┓┏┓┏┓┏┫${txtbld}" && tput el && printf "\\n"
            printf "  \_| \_/_|_|_|  \___/\_| \_/\___/ \__,_|\___|  ${txtrst}┻┛┗┻┛┛┗┗┛┗┛┗┻┛ ┗┻" && tput el && printf "\\n"
            echo ""

            # STATUS MONITOR DASHBOARD - GENERATE NODE TABLE
            echo "$sm_row_01" # "╔" "═" "╦" "═" "╦" "═" "╗"

            # STATUS MONITOR DASHBOARD - KIIROCOIN NODE
            if [ "$KIIRO_STATUS" = "running" ]; then # Only display if Kiirocoin Node is running
                printf " ║ KIIROCOIN NODE ║    CONNECTIONS ║  " && printf "%-${col_width_kiiro_connections_max}s %29s %-3s\n" "$KIIRO_CONNECTIONS Nodes (v1.0.0.4: $KIIRO_CONNECTED_PEERS_NEW v1.0.0.3: $KIIRO_CONNECTED_PEERS_OLD)" "[ $KIIRO_CONNECTIONS_MSG ]" " ║ "
                # Choose the correct network chain border
                echo "$sm_row_02_mainnet" # "║" "(MAINNET)" "╠" "═" "╬" "═" "╣"
                printf " ║                ║   BLOCK HEIGHT ║  " && printf "%-${col_width_kiiro_blockheight}s %19s %-3s\n" "$KIIRO_BLOCKCOUNT_FORMATTED Blocks" "[ Synced: $KIIRO_BLOCKSYNC_PERC% ]" " ║ "
                echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
                # if [ $term_width -gt 121 ]; then 
                #     printf " ║                ║    NODE UPTIME ║  " && printf "%-${col_width_kiiro_uptime_long}s %19s %-3s\n" "$kiiro_uptime" "[ Online Since: $kiiro_online_since ]" " ║ "
                # else
                #     printf " ║                ║    NODE UPTIME ║  " && printf "%-${col_width_kiiro_uptime}s %-3s\n" "$kiiro_uptime" " ║ "
                # fi
                # echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
                printf " ║                ║          PORTS ║  " && printf "%-${col_width_kiiro_ports}s %-3s\n" "Listening Port: ${KIIRO_LISTEN_PORT}   RPC Port: $kiiro_rpcport_display" " ║ "
                echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
                if [ "$KIIRO_CURRENT_VERSION" != "$KIIRO_LATEST_VERSION" ]; then
                    printf " ║                ║        VERSION ║  " && printf "%-${col_width_kiiro_version_long}s %-3s\n" "$KIIRO_CURRENT_VERSION${txtred} (outdated)${txtrst}" " ║ "
                else
                    printf " ║                ║        VERSION ║  " && printf "%-${col_width_kiiro_version}s %-3s\n" "$KIIRO_CURRENT_VERSION" " ║ "
                fi
                echo "$sm_row_05" # "╚" "═" "╩" "═" "╩" "═" "╝"
    
                echo "$sm_row_01" # "╔" "═" "╦" "═" "╦" "═" "╗"
                if [ $KIIRO_EVO_STATE = "READY" ] || [ $KIIRO_EVO_STATE = "POSE_BANNED" ]; then
                    KIIRO_EVO_NEEDTOUPGRADE_MSG="No "
                    if [ "$KIIRO_EVO_NEEDTOUPGRADE" = "true" ]; then
                        KIIRO_EVO_NEEDTOUPGRADE_MSG="${txtred}Yes${txtrst}"
                    fi
                fi
                if [ $KIIRO_EVO_STATE = "READY" ]; then
                    printf " ║ MASTERNODE     ║         STATUS ║  " && printf "%-${col_width_kiiro_masternode}s %-3s\n" "$KIIRO_EVO_STATUS" " ║ "
                    printf " ║                ║     PROTX HASH ║  " && printf "%-${col_width_kiiro_masternode}s %-3s\n" "$KIIRO_EVO_PROTXHASH" " ║ "
                    printf " ║                ║     COLLATERAL ║  " && printf "%-${col_width_kiiro_masternode_long}s %29s %-3s\n" "$KIIRO_EVO_COLLATERALAMOUNT" "[ Need Upgrade: $KIIRO_EVO_NEEDTOUPGRADE_MSG ]" " ║ "
                    printf " ║                ║    PAID HEIGHT ║  " && printf "%-${col_width_kiiro_masternode}s %-3s\n" "$KIIRO_EVO_LASTPAIDHEIGHT" " ║ "
                    echo "$sm_row_05" # "╚" "═" "╩" "═" "╩" "═" "╝"
                elif [ $KIIRO_EVO_STATE = "POSE_BANNED" ]; then
                    printf " ║ MASTERNODE     ║         STATUS ║  " && printf "%-${col_width_kiiro_masternode}s %-3s\n" "$KIIRO_EVO_STATUS" " ║ "
                    printf " ║                ║     PROTX HASH ║  " && printf "%-${col_width_kiiro_masternode}s %-3s\n" "$KIIRO_EVO_PROTXHASH" " ║ "
                    printf " ║                ║     COLLATERAL ║  " && printf "%-${col_width_kiiro_masternode_long}s %29s %-3s\n" "$KIIRO_EVO_COLLATERALAMOUNT" "[ Need Upgrade: $KIIRO_EVO_NEEDTOUPGRADE_MSG ]" " ║ "
                    printf " ║                ║     BAN HEIGHT ║  " && printf "%-${col_width_kiiro_masternode}s %-3s\n" "$KIIRO_EVO_POSEBANHEIGHT"  " ║ "
                    echo "$sm_row_05" # "╚" "═" "╩" "═" "╩" "═" "╝"
                elif [ $KIIRO_EVO_STATE = "WAITING_FOR_PROTX" ]; then
                    printf " ║ MASTERNODE     ║         STATUS ║  " && printf "%-${col_width_kiiro_masternode}s %-3s\n" "$KIIRO_EVO_STATUS" " ║ "
                    echo "$sm_row_05" # "╚" "═" "╩" "═" "╩" "═" "╝"
                else
                    printf " ║ MASTERNODE     ║         STATUS ║  " && printf "%-${col_width_kiiro_masternode}s %-3s\n" "$KIIRO_EVO_STATUS" " ║ "
                    printf " ║                ║     PROTX HASH ║  " && printf "%-${col_width_kiiro_masternode}s %-3s\n" "$KIIRO_EVO_PROTXHASH" " ║ "
                    echo "$sm_row_05" # "╚" "═" "╩" "═" "╩" "═" "╝"
                fi

            fi

            if [ "$KIIRO_STATUS" = "stopped" ]; then # Only display if Kiirocoin Node is stopped running
                printf " ║ KIIROCOIN NODE ║         STATUS ║  " && printf "%-${col_width_kiiro_status}s %-3s\n" "${txtred}Kiirocoin $kiiro_chain_caps Node is not running.${txtrst}" " ║ "
                echo "$sm_row_05" # "╚" "═" "╩" "═" "╩" "═" "╝"
            fi

            if [ "$KIIRO_STATUS" = "not_detected" ]; then # Only display if Kiirocoin Node is not detected
                printf " ║ KIIROCOIN NODE ║         STATUS ║  " && printf "%-${col_width_kiiro_status}s %-3s\n" "${txtred}Kiirocoin Node not detected.${txtrst}" " ║ "
                echo "$sm_row_05" # "╚" "═" "╩" "═" "╩" "═" "╝"
            fi

            # Display IP4 External address
            echo "$sm_row_01" # "╔" "═" "╦" "═" "╦" "═" "╗"
            ip4_leftcol=" ║ NETWORK        ║    IP4 ADDRESS ║  "
            db_content_c1_c2_c3f "$ip4_leftcol" "External: $IP4_EXTERNAL"
            echo "$sm_row_03" # "╠" "═" "╬" "═" "╬" "═" "╣"

            # STATUS MONITOR DASHBOARD - SYSTEM - DEVICE
            if [ "$MODEL" != "" ]; then
                col_1_2_text=" ║ SYSTEM         ║         DEVICE ║  "
                col3_text="$MODEL"
                col4_text="${MODELMEM}B RAM"
                db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
                echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
            fi

            # STATUS MONITOR DASHBOARD - SYSTEM - DISK USAGE
            # Display the section title, if the device was not displayed above
            if [ "$MODEL" != "" ]; then
                col_1_2_text=" ║                ║     DISK USAGE ║  "
            else
                col_1_2_text=" ║ SYSTEM         ║     DISK USAGE ║  "
            fi

            if [ "$KIIRO_DATA_DISKUSED_PERC_CLEAN" -ge "80" ]; then # Display current disk usage percentage in red if it is 80% or over
                col3_text="${KIIRO_DATA_DISKUSED_HR}b of ${KIIRO_DATA_DISKTOTAL_HR}b ( ${dbcol_bred}$KIIRO_DATA_DISKUSED_PERC${dbcol_rst} )"
                col4_text="${KIIRO_DATA_DISKFREE_HR}b free"
                db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
            else
                col3_text="${KIIRO_DATA_DISKUSED_HR}b of ${KIIRO_DATA_DISKTOTAL_HR}b ( $KIIRO_DATA_DISKUSED_PERC )"
                col4_text="${KIIRO_DATA_DISKFREE_HR}b free"
                db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
            fi

            echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"

            # STATUS MONITOR DASHBOARD - SYSTEM - MEMORY USAGE

            col_1_2_text=" ║                ║   MEMORY USAGE ║  "
            col3_text="${RAMUSED_HR}b of ${RAMTOTAL_HR}b"
            col4_text="${RAMAVAIL_HR}b free"
            db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
            echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"

            # STATUS MONITOR DASHBOARD - SYSTEM - SWAP USAGE

            if [ "$SWAPTOTAL_HR" != "0B" ] && [ "$SWAPTOTAL_HR" != "" ]; then # only display the swap file status if there is one, and the current value is above 0B
                col_1_2_text=" ║                ║     SWAP USAGE ║  "
                if [ "$SWAPUSED_HR" = "0B" ]; then # If swap used is 0B, drop the added b, used for Gb or Mb
                    col3_text="${SWAPUSED_HR} of ${SWAPTOTAL_HR}b"
                    col4_text="${SWAPAVAIL_HR}b free"
                    db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
                else
                    col3_text="${SWAPUSED_HR}b of ${SWAPTOTAL_HR}b"
                    col4_text="${SWAPAVAIL_HR}b free"
                    db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
                fi
                echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
            fi

            # STATUS MONITOR DASHBOARD - SYSTEM - CPU USAGE (Only displays with 12 cores or less)

            if [ "$cpu_cores" -le 12 ]; then

                # Read CPU values from the temporary files (these are updated by a background process)
                cpu_usage_1=$(cat "$cpu1_file")
                cpu_usage_2=$(cat "$cpu2_file")
                average_cpu_usage=$(cat "$avg_file")

                # Setup CPU display array
                cpu_leftcol=" ║                ║      CPU USAGE ║  "
                cpu_leftcol2=" ║                ║                ║  "
                cpu_one_line="$cpu_usage_1$cpu_usage_2"
                cpu_one_line_width=${#cpu_one_line}
                cpu_one_line_l1="$cpu_usage_1"
                cpu_one_line_l2="$cpu_usage_2"
                cpu_total_perc="Total: ${average_cpu_usage}%"
                cpu_total_perc_width=${#cpu_total_perc}

                if [ $term_width -gt $((cpu_one_line_width + combined_col1_2_width + cpu_total_perc_width + right_border_width)) ]; then
                    db_content_c1_c2_c3f_c4 "$cpu_leftcol" "$cpu_one_line" "$cpu_total_perc"
                else
                    db_content_c1_c2_c3f_c4 "$cpu_leftcol" "$cpu_one_line_l1" "$cpu_total_perc"
                    db_content_c1_c2_c3f "$cpu_leftcol2" "$cpu_one_line_l2"
                fi

                echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"

            fi

            # STATUS MONITOR DASHBOARD - SYSTEM - CLOCK
            col_1_2_text=" ║                ║   SYSTEM CLOCK ║  "
            col3_text="$TIME_NOW"
            db_content_c1_c2_c3f "$col_1_2_text" "$col3_text"

            echo "$sm_row_05" # "╚" "═" "╩" "═" "╩" "═" "╝"

            # Print empty line
            printf "%${term_width}s\n"

            ##########################################

            # STATUS MONITOR DASHBOARD - QUIT MESSAGE
            echo "$quit_message"

            tput ed

        )

        if [ "$STARTUP_LOOP" = true ]; then

            printf "%b Startup Loop Completed.\\n" "${INFO}"

            printf "\\n"

            # Log date of this Dashboard run to kiironode.settings
            str="Logging date of this run to kiironode.settings file..."
            printf "%b %s" "${INFO}" "${str}"
            sed -i -e "/^KIIRO_MONITOR_LAST_RUN=/s|.*|KIIRO_MONITOR_LAST_RUN=\"$(date)\"|" $KIIRO_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            printf "\\n"

            echo "               < Wait for 3 seconds >"
            sleep 3

            tput smcup
            #   tput civis

            # Hide the cursor.
            printf '\e[?25l'

            # Disabling line wrapping.
            printf '\e[?7l'

            # Hide user input
            stty -echo

            STARTUP_LOOP=false

        fi

        # end output double buffer
        if [ "$terminal_resized" = "no" ]; then
            change_tip="yes"
            echo "$output"
        fi

        # Display the quit message on exit
        trap quit_message EXIT
        trap ctrl_c INT

        # sleep 1
        read -t 0.5 -s -n 1 input
        case "$input" in
        "Q")
            break
            ;;
        "q")
            break
            ;;
        esac

        if [ "$EXIT_DASHBOARD" = true ]; then
            break
        fi

        # Any key press resets the loopcounter
        if [ "${#input}" != 0 ]; then
            loopcounter=0
        fi

    done

}

main_menu() {
    banner
    display_help

    local str="Root user check"
    printf "\\n"

    # If the user's id is zero,
    if [[ "${EUID}" -eq 0 ]]; then
        # they are root and all is good
        printf "%b %s\\n\\n" "${TICK}" "${str}"
    else
        # Do not have enough privileges, so let the user know
        printf "%b %s\\n" "${INFO}" "${str}"
        printf "%b %bScript called with non-root privileges%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b KiiroNode Setup requires elevated privileges to get started.\\n" "${INDENT}"
        printf "%b Please review the source code on GitHub for any concerns regarding this\\n" "${INDENT}"
        printf "%b requirement. Make sure to run this script from a trusted source.\\n\\n" "${INDENT}"
        printf "%b Sudo utility check" "${INFO}"

        # If the sudo command exists, try rerunning as admin
        if is_command sudo; then
            printf "%b%b Sudo utility check\\n" "${OVER}" "${TICK}"

            # when run via curl piping
            if [[ "$0" == "bash" ]]; then
                printf "%b Re-running KiiroNode URL as root...\\n" "${INFO}"
                # Download the install script and run it with admin rights
                exec curl -sSL $KIIRONODE_URL | sudo bash -s -- --runremote "$@" 
            else
                # when run via calling local bash script
                printf "%b Re-running KiiroNode as root...\\n" "${INFO}"
                exec sudo bash "$0" --runlocal "$@"
            fi
            exit $?
        else
            # Otherwise, tell the user they need to run the script as root, and bail
            printf "%b  %b Sudo utility check\\n" "${OVER}" "${CROSS}"
            printf "%b Sudo is needed for KiiroNode Setup to proceed.\\n\\n" "${INFO}"
            printf "%b %bPlease re-run as root.${COL_NC}\\n" "${INFO}" "${COL_LIGHT_RED}"
            exit 1
        fi
    fi

    # Install dependencies
    echo ""
    printf "%b Checking for / installing required dependencies for KiiroNode Setup...\\n" "${INFO}"
    install_dependent_packages "${SETUP_DEPS[@]}"
    set_sys_variables           # Set various system variables once we know we are on linux
    kiironode_import_settings   # Create kiironode.settings file (if it does not exist)
    kiironode_create_settings   # Create kiiroinode.settings file (if it does not exist)
    is_kiironode_installed      # Run checks to see if Kiirocoin Node is present. Exit if it isn't. Import kiirocoin.conf.

    printf " =============== INSTALL MENU ==========================================\\n\\n"
    # ==============================================================================

    opt1a="Setup Masternode "
    opt1b=" Install Kiirocoin Masternode."

    opt2a="Upgrade Version "
    opt2b=" Upgrade Kiirocoin version to ${KIIRO_LATEST_VERSION}."

    opt3a="Run EVOZNODE Status "
    opt3b=" Check Masternode Status."

    opt4a="Display Dashboard "
    opt4b=" Display your Masternode Dashboard."

    KIIRO_CURRENT_VERSION=$KIIRO_LATEST_VERSION
    if [ $KIIRO_STATUS != "not_detected" ]; then
        KIIRO_CURRENT_VERSION=$($KIIRO_CLI -version 2>/dev/null | cut -d ' ' -f6 | cut -d '-' -f1)
    fi

    if [ $KIIRO_STATUS != "not_detected" ] && [ "$KIIRO_CURRENT_VERSION" != "$KIIRO_LATEST_VERSION" ]; then
        KIIRO_MENU_MESSAGE="You are running version $KIIRO_CURRENT_VERSION of Kiirocoin Core on this machine, you can upgrade to version $KIIRO_LATEST_VERSION."
    elif [ $KIIRO_STATUS = "not_detected" ]; then
        KIIRO_MENU_MESSAGE="Select 'Setup Masternode' to install $KIIRO_LATEST_VERSION of Kiirocoin Core. Please have your BLS private key handy."
    elif [ $KIIRO_STATUS != "not_detected" ] && [ "$KIIRO_CURRENT_VERSION" = "$KIIRO_LATEST_VERSION" ]; then
        KIIRO_MENU_MESSAGE="You are already running the latest version of Kiirocoin Core. You can check your Masternode status with the 'Display Dashboard' selection."
    else
        KIIRO_MENU_MESSAGE="If you already have a Kiirocoin Node on this machine, you can upgrade to the latest version."
    fi

    # Display the information to the user
    UpdateCmd=$(whiptail --title "KiiroNode - Main Menu" --menu "\\n\\n$KIIRO_MENU_MESSAGE\\n\\nPlease choose an option:\\n" --cancel-button "Exit" 18 70 4 \
        "${opt1a}" "${opt1b}" \
        "${opt2a}" "${opt2b}" \
        "${opt3a}" "${opt3b}" \
        "${opt4a}" "${opt4b}" 3>&2 2>&1 1>&3) ||
        {
            printf "%b %bExit was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
            exit
        }

    # Set the variable based on if the user chooses
    case ${UpdateCmd} in
    # Setup Masternode
    ${opt1a})
        printf "%b %soption selected\\n" "${INFO}" "${opt1a}"
        install_masternode
        ;;
    # Upgrade Masternode Version
    ${opt2a})
        printf "%b %soption selected\\n" "${INFO}" "${opt2a}"
        upgrade_masternode
        ;;
    # Show Masternode Status
    ${opt3a})
        printf "%b %soption selected\\n" "${INFO}" "${opt3a}"
        run_evoznode_status
        ;;
    # Show Dashboard
    ${opt4a})
        printf "%b %soption selected\\n" "${INFO}" "${opt4a}"
        display_dashboard
        ;;
    esac
    printf "\\n"
}

while true; do
    banner
    main_menu
    if [ "$UpdateCmd" != "$opt4a" ]; then
        read -p "Press Enter to continue..."
    fi
done
