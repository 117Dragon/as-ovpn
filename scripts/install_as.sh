#!/bin/bash 

# Variables
# Get local ip-address
ip_addr=$(ip a | grep -m 1 'scope global' | awk '{print $2}')
# path ovpnas
AS=/usr/local/openvpn_as/lib/python/
# All files of patch
PATCH=/tmp/patch/
# Patch files
PFILE=pyovpn-2.0-py3.10.egg
# Let's Encrypt path
LPATH=/etc/letsencrypt/archive/

# Create certificates
echo "*************************************************************************\n
*************************************************************************\n
****  Don't forget to open or redirect port 80 for the OpenVPN Server  **\n
*************************************************************************\n
*************************************************************************"
sleep 10

echo "Enter domain for create a certificate"
read DOMAIN
echo "Enter your e-mail for renewal and security notices"
read EMAIL
certbot certonly --standalone --email $EMAIL --preferred-challenges http -d $DOMAIN
sleep 5

# Preparation to patching
ARCHIVE="/tmp/as-ovpn/data/data.zip"
PS="Orwell-1984"
mkdir -p $PATCH
sudo systemctl stop openvpnas
sudo cp $AS$PFILE $AS$PFILE 
sudo cp $AS$PFILE $PATCH
unzip $PATCH$PFILE -d "$PATCH"tmp
unzip -P $PS $ARCHIVE -d $PATCH

## Preparation the nginx for SSL
# Make directory for SSL
sudo mkdir -p /etc/nginx/ssl/$DOMAIN

# Make certificate for nginx
sudo cat $LPATH$DOMAIN/cert1.pem $LPATH$DOMAIN/fullchain1.pem > $LPATH$DOMAIN/fullchain_nginx.pem 
sudo mv $LPATH$DOMAIN/fullchain_nginx.pem /etc/nginx/ssl/$DOMAIN/
sudo cp $LPATH$DOMAIN/privkey1.pem /etc/nginx/ssl/$DOMAIN/

# Replace domain in nginx configs
sed -i 's/example.com/'$DOMAIN'/g' /tmp/temp_patch/data_zip/nginx/crt.conf /tmp/temp_patch/data_zip/nginx/vhost.conf

# Add symlink and remove default vHost
sudo cp "$PATCH"nginx/crt.conf /etc/nginx/ssl/$DOMAIN/
sudo cp "$PATCH"nginx/proxy.conf /etc/nginx/conf.d/
sudo cp "$PATCH"nginx/ssl.conf /etc/nginx/conf.d/
sudo cp "$PATCH"nginx/vhost.conf /etc/nginx/sites-available/$DOMAIN/
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl start nginx

# Add symlink and remove default vHost
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl start nginx

# Replace
cp "$PATCH"patch/info.pyc "$PATCH"tmp/pyovpn/lic/info.pyc

# Make .egg and patching
zip -r "$PATCH"tmp/patch/pyovpn-2.0-py3.10.egg /tmp/temp_egg/*
sudo cp /tmp/pyovpn-2.0-py3.10.egg /usr/local/openvpn_as/lib/python/pyovpn-2.0-py3.10.egg

# Save file for next download
sudo mkdir -p /tmp/patch
sudo cp /tmp/temp_patch/data_zip/patch/openvpn-as-kg.exe /tmp/temp_patch/data_zip/patch/readme.txt /tmp/patch/

# Make script for install 
sudo cat <<EOL > /usr/local/sbin/certbotrenew.sh
#!/bin/bash
sudo /usr/local/openvpn_as/scripts/sacli --key "cs.priv_key" --value_file "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "cs.cert" --value_file "/etc/letsencrypt/live/$DOMAIN/cert.pem" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "cs.ca_bundle" --value_file "/etc/letsencrypt/live/$DOMAIN/chain.pem" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli start
EOL
sleep 3

# Make file exec
sudo chmod +x /usr/local/sbin/certbotrenew.sh

# Exec script
sudo bash /usr/local/sbin/certbotrenew.sh

# Make crontab
sudo echo "0 8 1 * * /usr/local/sbin/certbotrenew.sh" >> /etc/crontab

# Start OVPNAS
sudo systemctl start openvpnas

# Remove template dir
#rm -rf /tmp/temp_egg /tmp/temp_patch/

# Information message
echo "*******************************************************************************************************************************"
sudo grep -A 1 -B 1 "Client" /usr/local/openvpn_as/init.log\n
echo "*********************************************************************************************************************************\n
****  !!!!!  Auth on https://$ip_addr:943/admin  ********************************************************************************\n
****  !!!!!  Be sure to replace the value with your own (domain):  **************************************************************\n
****  !!!!!  Admin  UI - Network Setting - Hostname to your previously specified domain:   **************************************\n
*********************************************************************************************************************************\n
*********************************************************************************************************************************\n
****  !!!!!  Download patch from "/tmp/patch"  **********************************************************************************\n
*********************************************************************************************************************************"
