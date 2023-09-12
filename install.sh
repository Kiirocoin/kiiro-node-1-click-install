#!/bin/bash
# Check if user is root
if [ "$EUID" -ne 0 ]
  then banner; echo "Please run as root"
  exit
fi

function banner {
orange='\033[0;33m'
sleep 4 && clear
printf "${orange}
██   ██ ██ ██ ██████   ██████   ██████  ██████  ██ ███    ██ 
██  ██  ██ ██ ██   ██ ██    ██ ██      ██    ██ ██ ████   ██ 
█████   ██ ██ ██████  ██    ██ ██      ██    ██ ██ ██ ██  ██ 
██  ██  ██ ██ ██   ██ ██    ██ ██      ██    ██ ██ ██  ██ ██ 
██   ██ ██ ██ ██   ██  ██████   ██████  ██████  ██ ██   ████"
echo ""
printf "
███    ███  █████  ███████ ████████ ███████ ██████  ███    ██  ██████  ██████  ███████ 
████  ████ ██   ██ ██         ██    ██      ██   ██ ████   ██ ██    ██ ██   ██ ██      
██ ████ ██ ███████ ███████    ██    █████   ██████  ██ ██  ██ ██    ██ ██   ██ █████   
██  ██  ██ ██   ██      ██    ██    ██      ██   ██ ██  ██ ██ ██    ██ ██   ██ ██      
██      ██ ██   ██ ███████    ██    ███████ ██   ██ ██   ████  ██████  ██████  ███████"
echo ""
printf "
██ ███    ██ ███████ ████████  █████  ██      ██      ███████ ██████  
██ ████   ██ ██         ██    ██   ██ ██      ██      ██      ██   ██ 
██ ██ ██  ██ ███████    ██    ███████ ██      ██      █████   ██████  
██ ██  ██ ██      ██    ██    ██   ██ ██      ██      ██      ██   ██ 
██ ██   ████ ███████    ██    ██   ██ ███████ ███████ ███████ ██   ██"
echo ""
sleep 2
}
banner
#vpsIp=`ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`
echo ""
#echo "Please enter VPS IP address: ${vpsIp} (Press enter if this is correct)"
echo "Please enter VPS IP address only: example 123.456.789.012 - DO NOT ADD PORT"
read vpsIp
#if [ -z "$vpsIp" ]
#then
#      vpsIp=`ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`
#fi
echo "Please enter BLS generated Secret: "
read blsSecret
echo ""
echo ""
echo "***************************"
echo "Updating & Installing unzip"
echo "***************************"
echo ""
sudo apt update && sudo apt-get install unzip -f
echo "Downloading ubuntu-18 Kiiro wallet"
sudo rm -f ubuntu-18.zip && wget https://github.com/Kiirocoin/kiiro/releases/download/v1.0.0.3/ubuntu-18.zip
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner
echo ""
echo "***************************"
echo "Unzipping"
echo "***************************"
echo ""
unzip -o ubuntu-18.zip
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner
echo ""
echo "***************************"
echo "Moving files to /usr/bin"
echo "***************************"
echo ""
sudo mv -f ubuntu-18/kiirocoin-cli /usr/bin && sudo mv -f ubuntu-18/kiirocoind /usr/bin
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner
echo ""
echo "***************************"
echo "Chmod files as executable"
echo "***************************"
echo ""
chmod +x /usr/bin/kiirocoin-cli && chmod +x /usr/bin/kiirocoind
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner
echo ""
echo "**********************************"
echo "Creating directory for node files"
echo "**********************************"
echo ""
mkdir -p ~/.kiirocoin
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner

echo ""
echo "*******************************"
echo "Making kiirocoind service file"
echo "*******************************"
echo ""
rpcuser=`tr -dc A-Za-z0-9 </dev/urandom | head -c 12`
rpcpassword=`tr -dc A-Za-z0-9 </dev/urandom | head -c 12`

cat <<EOT > /etc/systemd/system/kiirocoind.service
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
EOT
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner
echo ""
echo "**********************************"
echo "Enabling kiirocoind service"
echo "**********************************"
echo ""
sudo systemctl enable kiirocoind
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner
echo ""
echo "**********************************"
echo "Setting and Enabling Firewall"
echo "**********************************"
echo ""
apt install -y ufw && ufw allow ssh/tcp && ufw limit ssh/tcp && ufw allow 8999/tcp && ufw logging on && ufw --force enable
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner
echo ""
echo "**********************************"
echo "Creating directory for node files"
echo "**********************************"
echo ""
mkdir -p ~/.kiirocoin
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner
echo ""
echo "***************************"
echo "Making kiirocoin.conf file"
echo "***************************"
echo ""
rpcuser=`tr -dc A-Za-z0-9 </dev/urandom | head -c 12`
rpcpassword=`tr -dc A-Za-z0-9 </dev/urandom | head -c 12`

cat <<EOT > ~/.kiirocoin/kiirocoin.conf
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
externalip=${vpsIp}:8999
znodeblsprivkey=${blsSecret}
EOT
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner
echo ""
echo "***************************"
echo "Removing old files"
echo "***************************"
echo ""
sudo rm -rd ubuntu-18 && sudo rm ubuntu-18.zip*
echo ""
echo "***************************"
echo "Done"
echo "***************************"
banner
echo ""
echo "Install of Masternode is complete."
echo ""
echo "Starting Masternode and waiting 10 seconds"
#kiirocoind -daemon
systemctl start kiirocoind
echo ""
sleep 10
echo "Running kiirocoin-cli evoznode status"
kiirocoin-cli evoznode status
echo ""
echo "If you do not see ready then run the following command again:"
echo ""
echo "kiirocoin-cli evoznode status"
echo "" 
echo "If you are receiving an error, you may have not properly registered Masternode or entered wrong information in beginning of install script"
echo ""
echo "Reach out to us on Discord if you need any help"
echo ""
echo "https://discord.gg/g88D2RP9"
