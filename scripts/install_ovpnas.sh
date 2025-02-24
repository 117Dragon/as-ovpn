#!/bin/bash 

# Get local ip-address
ip_addr=$(ip a | grep -m 1 'scope global' | awk '{print $2}')

## MySQL
# sudo apt install mysql-server libmysqlclient-dev  mysql-client 
#sudo systemctl start mysql.service
## MySQL set secure
# mysql_secure_installation
## sudo cat /usrl/local/openvpn_as/init.log

# Let's Encrypt install and configuring for OpenVPN Access Server
sudo apt update && sudo apt -y install certbot
sleep 10

# Create certificates
echo "**********************************************************************\n
**********************************************************************\n
****  Don't forget to open or redirect port 80 for the OpenVPN Server  **\n
**********************************************************************\n
**********************************************************************"
echo "Enter domain for create a certificate"
read DOMAIN
echo "Enter your e-mail for renewal and security notices"
read EMAIL
certbot certonly --standalone --email $EMAIL --preferred-challenges http -d $DOMAIN
sleep 10

## Preparation the nginx for SSL
# Make directory for SSL
sudo mkdir -p /etc/nginx/ssl/$DOMAIN

# Make certificate file for nginx from certbot "cert1.pem" and "fullchain1.pem"
sudo cat /etc/letsencrypt/archive/$DOMAIN/cert1.pem /etc/letsencrypt/archive/$DOMAIN/fullchain1.pem > /etc/nginx/ssl/$DOMAIN/fullchain.pem
sudo cp /etc/letsencrypt/archive/$DOMAIN/privkey1.pem /etc/nginx/ssl/$DOMAIN/

# Make script for install 
sudo cat <<EOL > /usr/local/sbin/certbotrenew.sh
#!/bin/bash
sudo /usr/local/openvpn_as/scripts/sacli --key "cs.priv_key" --value_file "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "cs.cert" --value_file "/etc/letsencrypt/live/$DOMAIN/cert.pem" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "cs.ca_bundle" --value_file "/etc/letsencrypt/live/$DOMAIN/chain.pem" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli start

# Make certificate for nginx
sudo cat /etc/letsencrypt/archive/$DOMAIN/cert1.pem /etc/letsencrypt/archive/$DOMAIN/fullchain1.pem > /etc/letsencrypt/archive/$DOMAIN/fullchain_nginx.pem 
sudo mv /etc/letsencrypt/archive/$DOMAIN/fullchain_nginx.pem /etc/nginx/ssl/$DOMAIN/
sudo cp /etc/letsencrypt/archive/$DOMAIN/privkey1.pem /etc/nginx/ssl/$DOMAIN/
sudo systemctl restart nginx
EOL

sleep 3

# Make file exec
sudo chmod +x /usr/local/sbin/certbotrenew.sh

# Exec script
sudo sh /usr/local/sbin/certbotrenew.sh

# Make crontab
sudo echo "0 8 1 * * /usr/local/sbin/certbotrenew.sh" >> /etc/crontab

# Preparation for patching
sudo systemctl stop openvpnas
sudo cp /usr/local/openvpn_as/lib/python/pyovpn-2.0-py3.10.egg /usr/local/openvpn_as/lib/python/pyovpn-2.0-py3.10.egg_
sudo cp /usr/local/openvpn_as/lib/python/pyovpn-2.0-py3.10.egg /tmp/pyovpn-2.0-py3.10.egg

# Patching 
ARCHIVE="/tmp/as-ovpn/data/data.zip"
PS="Orwell-1984"
mkdir -p /tmp/temp_egg
mkdir -p /tmp/temp_patch
unzip pyovpn-2.0-py3.10.egg -d /tmp/temp_egg
unzip -P "$PS" "$ARCHIVE" -d /tmp/temp_patch

# Replace
cp /tmp/temp_patch/info.pyc /tmp/temp_egg/pyovpn/lic/info.pyc

# Make .egg and patching
zip -r /tmp/pyovpn-2.0-py3.10.egg /tmp/temp_egg/*
sudo cp /tmp/pyovpn-2.0-py3.10.egg /usr/local/openvpn_as/lib/python/pyovpn-2.0-py3.10.egg

# Save file for next download
sudo mkdir -p /tmp/patch
sudo cp /tmp/temp_patch/openvpn-as-kg.exe /tmp/temp_patch/readme.txt /tmp/patch

# Replace domain in nginx configs
sed -i 's/example.com/'$DOMAIN'/g' /tmp/temp_patch/nginx/crt.conf /tmp/temp_patch/nginx/vhost.conf

# Add symlink and remove default vHost
sudo mkdir -p /etc/nginx/ssl
sudo cp /tmp/temp_patch/nginx/crt.conf /etc/nginx/ssl/$DOMAIN/crt.conf
sudo cp /tmp/temp_patch/nginx/proxy.conf /etc/nginx/conf.d/
sudo cp /tmp/temp_patch/nginx/ssl.conf /etc/nginx/conf.d/
sudo cp /tmp/temp_patch/nginx/vhost.conf /etc/nginx/sites-available/$DOMAIN
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl start nginx

# Remove template dir
rm -rf /tmp/temp_egg /tmp/temp_patch/

# Start OVPNAS
sudo systemctl start openvpnas

# Information message
echo "*******************************************************************************************************************************"
sudo grep -A 1 -B 1 "Client" /usr/local/openvpn_as/init.log
echo "*******************************************************************************************************************************\n
****  !!!!!Auth on https://$ip_addr:943/admin  ********************************************************************************\n
****  !!!!!Be sure to replace the value with your own (domain):!!!!!!  ********************************************************\n
****  !!!!!'Admin  UI - Network Setting - Hostname to your previously specified domain:'!!!!!!  *******************************\n
echo "*******************************************************************************************************************************\n
*******************************************************************************************************************************\n
****  Download patch from "/tmp/patch"  *******************************************************************\n
*******************************************************************************************************************************"
