#!/bin/bash

# Install OVPN Access Server
sudo timedatectl set-timezone Europe/Moscow
sudo apt update && sudo apt -y install ca-certificates wget net-tools gnupg mc net-tools ncdu fail2ban git
sudo mkdir -p /etc/apt/keyrings && sudo curl -fsSL https://packages.openvpn.net/as-repo-public.asc | sudo tee /etc/apt/keyrings/as-repository.asc
sudo echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/as-repository.asc] http://packages.openvpn.net/as/debian jammy main" | sudo tee /etc/apt/sources.list.d/openvpn-as-repo.list
sudo apt update && sudo apt -y install openvpn-as
sudo systemctl stop openvpnas

# Patching
git clone git@github.com:117Dragon/as-ovpn.git
cd as-ovpn && mv data pyovpn-2.0-py3.10.egg && sudo pyovpn-2.0-py3.10.egg /usr/local/openvpn_as/lib/python/
sudo systemctl start openvpnas

# Ask about use Let's Encrypt 
read -p "Do you want to create a certificate using Let's Encrypt? (yes/no): " answer

# We reduce the answer to lowercase to simplify verification.
answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

if [[ "$answer" == "yes" ]]; then

# Let's Encrypt install and configuring for OpenVPN Access Server
sudo apt update && sudo apt -y install certbot

# Create certificates
echo "****************************************************************** /
****************************************************************** /
****Don't forget to open/redirect port 80 for the OpenVPN Server** /
****************************************************************** /
******************************************************************"
echo "Enter domain for create a certificate"
read DOMAIN
echo "Enter your e-mail for renewal and security notices"
read EMAIL
certbot certonly --standalone --email $EMAIL --preferred-challenges http -d $DOMAIN

# Make script for install 
cat << 'EOF' | sudo tee /usr/local/sbin/certbotrenew.sh
#!/bin/bash
sudo /usr/local/openvpn_as/scripts/sacli --key "cs.priv_key" --value_file "/etc/letsencrypt/live/sslexample.com/privkey.pem" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "cs.cert" --value_file "/etc/letsencrypt/live/sslexample.com/cert.pem" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "cs.ca_bundle" --value_file "/etc/letsencrypt/live/sslexample.com/chain.pem" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli start
EOF

# Make file exec
sudo chmod +x /usr/local/sbin/certbotrenew.sh

# Exec script
sudo sh /usr/local/sbin/certbotrenew.sh

# Make crontab
sudo echo "0 8 1 * * /usr/local/sbin/certbotrenew.sh" >> /etc/crontab

else
    # End of execution
    echo "The certificate has been issued and will be updated automatically."
    read -n 1 -s -r -p "----Press 'any key'----"
fi

# Information message
echo "******************************************************************************************************************************* \n
******************************************************************************************************************************* \n
****  1)  Admin  UI: https://{ovpn ip}:943/admin  ***************************************************************************** \n
****      Client UI: https://{ovpn ip}:943/       ***************************************************************************** \n
****  2)  If you haven't found the password from the user 'openvpn', then use the password reset script 'pass-reset.sh'  ****** \n
****  3)  Be sure to replace the value with your own (domain/ip): 'Admin  UI - Network Setting - Hostname or IP Address:'  **** \n
******************************************************************************************************************************* \n
****  P.S. keygen in the archive 'data2' | password: 'Orwell-1984'   ********************************************************** \n
******************************************************************************************************************************* \n
*******************************************************************************************************************************"



