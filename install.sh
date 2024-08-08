#!/bin/bash

function banner {
orange='\033[0;33m'
sleep 4 && clear
printf "${orange}
██   ██ ██ ██ ██████   ██████   ██████  ██████  ██ ███    ██ 
██  ██  ██ ██ ██   ██ ██    ██ ██      ██    ██ ██ ████   ██ 
█████   ██ ██ ██████  ██    ██ ██      ██    ██ ██ ██ ██  ██ 
██  ██  ██ ██ ██   ██ ██    ██ ██      ██    ██ ██ ██  ██ ██ 
██   ██ ██ ██ ██   ██  ██████   ██████  ██████  ██ ██   ████"
printf ""
printf "
███    ███  █████  ███████ ████████ ███████ ██████  ███    ██  ██████  ██████  ███████ 
████  ████ ██   ██ ██         ██    ██      ██   ██ ████   ██ ██    ██ ██   ██ ██      
██ ████ ██ ███████ ███████    ██    █████   ██████  ██ ██  ██ ██    ██ ██   ██ █████   
██  ██  ██ ██   ██      ██    ██    ██      ██   ██ ██  ██ ██ ██    ██ ██   ██ ██      
██      ██ ██   ██ ███████    ██    ███████ ██   ██ ██   ████  ██████  ██████  ███████"
printf ""
printf "
██ ███    ██ ███████ ████████  █████  ██      ██      ███████ ██████  
██ ████   ██ ██         ██    ██   ██ ██      ██      ██      ██   ██ 
██ ██ ██  ██ ███████    ██    ███████ ██      ██      █████   ██████  
██ ██  ██ ██      ██    ██    ██   ██ ██      ██      ██      ██   ██ 
██ ██   ████ ███████    ██    ██   ██ ███████ ███████ ███████ ██   ██"
printf ""
sleep 2
}

hr="\n\n****************************************************************************************\n\n";
# Check if user is root
if [ "$EUID" -ne 0 ]
  then banner; printf ""; root=0; printf "${hr}WARNING${hr}"; printf ""; printf "User is not root.\n\n"; printf "Script may fail with some operations if current user is not in sudo group or configured correctly.";sleep 4;
fi
banner
printf "${hr}"
vpsIp=`hostname -I | awk '{print $1}'`

printf "Your VPS IP = ${vpsIp}\n\n"
printf "If your VPS IP is not correct or is blank, please contact Kiirocoin Support team for assistance with editing kiirocoin.conf after this install\n\n"
printf "Please enter BLS generated Secret: \n"
read blsSecret
length=`expr length ${blsSecret//[[:blank:]]/}`;
if [ $length != 64 ];
then printf "\n\nblsSecret is not valid. Please restart script ( sudo bash kiiro-node-1-click-install/install.sh ) and enter a valid blsSecret.\n\n";exit;fi;
printf "${hr}Updating & Installing unzip${hr}"
sudo apt update && sudo apt-get install unzip -f
printf "Downloading ubuntu-18 Kiiro wallet"
if [ -f kiirocoin-1.0.0.6-linux-18.04.zip ] ; then
    sudo rm kiirocoin-1.0.0.6-linux-18.04.zip
fi
if [ -f kiirocoind ] ; then
    sudo rm kiirocoind
fi
if [ -f kiirocoin-cli ] ; then
    sudo rm kiirocoin-cli
fi
if [ -f kiirocoin-qt ] ; then
    sudo rm kiirocoin-qt
fi
if [ -f kiirocoin-tx ] ; then
    sudo rm kiirocoin-tx
fi
wget github.com/Kiirocoin/kiiro/releases/download/v1.0.0.6/kiirocoin-1.0.0.6-linux-18.04.zip
printf "${hr}Done${hr}"
banner
printf "${hr}Unzipping${hr}"
unzip -o kiirocoin-1.0.0.6-linux-18.04.zip
printf "${hr}Done${hr}"
banner
printf "${hr}Select directory kiirocoin-1.0.0.6-linux-18.04${hr}"
cd kiirocoin-1.0.0.6-linux-18.04
printf "${hr}Done${hr}"
banner
printf "${hr}Moving files to /usr/bin${hr}"
sudo mv -f kiirocoin-cli /usr/bin && sudo mv -f kiirocoind /usr/bin
printf "${hr}Done${hr}"
banner
printf "${hr}Chmod files as executable${hr}"
chmod +x /usr/bin/kiirocoin-cli && chmod +x /usr/bin/kiirocoind
printf "${hr}Done${hr}"
banner
printf "${hr}Creating kiirocoind service file${hr}"
sudo systemctl disable kiirocoind
if [ -f /etc/systemd/system/kiirocoind.service ] ; then
    sudo rm /etc/systemd/system/kiirocoind.service
fi
rpcuser=`tr -dc A-Za-z0-9 </dev/urandom | head -c 12`
rpcpassword=`tr -dc A-Za-z0-9 </dev/urandom | head -c 12`

#if [ $root=0 ];
#then FILE_NAME="/home/$USER/.kiirocoin/kiirocoind.pid";
#else FILE_NAME="/root/.kiirocoin/kiirocoind.pid";
#fi
cat <<EOF > /etc/systemd/system/kiirocoind.service
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


printf "${hr}Done${hr}"
banner
printf "${hr}Enabling kiirocoind service${hr}"
sudo systemctl enable kiirocoind.service
printf "${hr}Done${hr}"
banner
printf "${hr}Configuring and Enabling Firewall${hr}"
#sudo apt install -y ufw && sudo ufw allow ssh/tcp && sudo ufw limit ssh/tcp && sudo ufw allow 8999/tcp && sudo ufw logging on && sudo ufw --force enable
printf "${hr}Done${hr}"
banner
printf "${hr}Creating directory for Masternode files${hr}"
mkdir -p /root/.kiirocoin
printf "${hr}Done${hr}"
banner
printf "${hr}Making kiirocoin.conf file${hr}"
if [ -f /root/.kiirocoin/kiirocoin.conf ] ; then
    sudo rm /root/.kiirocoin/kiirocoin.conf
fi
rpcuser=`tr -dc A-Za-z0-9 </dev/urandom | head -c 12`
rpcpassword=`tr -dc A-Za-z0-9 </dev/urandom | head -c 12`
cat <<EOT > /root/.kiirocoin/kiirocoin.conf
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
externalip=${vpsIp//[[:blank:]]/}:8999
znodeblsprivkey=${blsSecret//[[:blank:]]/}
EOT

printf "${hr}Done${hr}"
banner
printf "${hr}Removing old files${hr}"
sudo rm kiirocoin-1.0.0.6-linux-18.04.zip && sudo rm kiirocoin-qt && sudo rm kiirocoin-tx
printf "${hr}Done${hr}"
banner
printf "${hr}Install of Masternode is complete.\n\n"
printf "Starting Masternode and waiting 10 seconds\n\n"
#kiirocoind -daemon
sudo systemctl start kiirocoind.service
sleep 10
printf "Running kiirocoin-cli evoznode status\n\n"
kiirocoin-cli evoznode status
printf "\n\nIf you do not see ready then run the following command again in 30 minutes:\n\n"
printf "sudo kiirocoin-cli evoznode status\n\n"
printf "If you are receiving an error, you may have not properly registered Masternode or entered wrong information in beginning of install script\n\n"
printf "Reach out to us on Discord if you need any help\n\n"
printf "https://discord.gg/g88D2RP9\n\n"
