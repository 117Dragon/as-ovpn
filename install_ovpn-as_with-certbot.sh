#!/bin/bash

# Get local ip-address
ip_addr=$(ip a | grep -m 1 'scope global' | awk '{print $2}')

# Install OVPN Access Server
sudo timedatectl set-timezone Europe/Moscow
sudo apt update && sudo apt -y install ca-certificates wget net-tools gnupg mc git ncdu fail2ban apt-transport-https ca-certificates nginx
sudo mkdir -p /etc/apt/keyrings && sudo curl -fsSL https://packages.openvpn.net/as-repo-public.asc | sudo tee /etc/apt/keyrings/as-repository.asc
sudo echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/as-repository.asc] http://packages.openvpn.net/as/debian jammy main" | sudo tee /etc/apt/sources.list.d/openvpn-as-repo.list
sudo apt update && sudo apt -y install openvpn-as
sudo systemctl stop nginx

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

## Preparation nginx for SSL
# Make directory for SSL
sudo mkdir /etc/nginx/ssl/$DOMAIN

# Make certificate file for nginx from certbot "cert1.pem" and "fullchain1.pem"
sudo cat /etc/letsencrypt/archive/$DOMAIN/cert1.pem /etc/letsencrypt/archive/$DOMAIN/fullchain1.pem > /etc/nginx/ssl/$DOMAIN/fullchain.pem
sudo cp /etc/letsencrypt/archive/$DOMAIN/privkey1.pem /etc/nginx/ssl/$DOMAIN/

# Make crt.conf
sudo cat <<EOL > /etc/nginx/ssl/$DOMAIN/crt.conf
    ssl_certificate       /etc/nginx/ssl/$DOMAIN/fullchain_nginx.pem;
    ssl_certificate_key   /etc/nginx/ssl/$DOMAIN/privkey1.pem;
EOL

# Make ssl.conf
sudo cat <<EOL > /etc/nginx/conf.d/ssl.conf
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_session_cache shared:SSL:50m;
    ssl_session_timeout 1d;
    resolver 8.8.4.4 8.8.8.8 valid=300s;
    resolver_timeout 10s;
    ssl_ciphers 'kEECDH+ECDSA+AES128 kEECDH+ECDSA+AES256 kEECDH+AES128 kEECDH+AES256 +SHA !aNULL !eNULL !LOW !MD5 !EXP !DSS !PSK !SRP !kECDH !CAMELLIA !RC4 !SEED';
    add_header Strict-Transport-Security max-age=15768000;
EOL

# Make proxy.config
sudo cat <<EOL > /etc/nginx/conf.d/proxy.conf
proxy_redirect off;
proxy_set_header 'Access-Control-Allow-Origin' '*';
proxy_set_header 'Access-Control-Allow-Credentials' 'true';
proxy_set_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE';
proxy_set_header 'Access-Control-Allow-Headers' 'X-Requested-With,Accept,Content-Type, Origin';
proxy_set_header X-Real-IP  $remote_addr;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-Server $host;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-For  $proxy_add_x_forwarded_for;
proxy_set_header Host $host;
#proxy_set_header    Host $http_host;
client_max_body_size 1024m;
client_body_buffer_size 128k;
#proxy_headers_hash_max_size 512;
#proxy_headers_hash_bucket_size 512;

proxy_connect_timeout 900;
proxy_send_timeout 900;
proxy_read_timeout 900;
proxy_buffer_size 32k;
proxy_buffers 32 32k;
proxy_busy_buffers_size 64k;
proxy_temp_file_write_size 64k;
send_timeout 900;
EOL

# Make vHost config
sudo cat <<EOL > /etc/nginx/sites-available/$DOMAIN
# Proxy_pass for OpenVPN AS

upstream ovpnas {
server 127.0.0.1:943;
}

server {
    listen        80;
    server_name   $DOMAIN;
    return        301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    error_log   /var/log/nginx/$DOMAIN.error.log;

    include /etc/nginx/conf.d/ssl.conf;
    include /etc/nginx/ssl/$DOMAIN/crt.conf;

    error_page  403 /403.html;
    location =  /403.html {
        root    /var/www/html/403;
        allow   all;
    }

    location / {
        proxy_pass  https://ovpnas;
        include     /etc/nginx/conf.d/proxy.conf;
    }
}
EOL

sudo systemctl start nginx

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

# Copy certificate for nginx conf

# Make file exec
sudo chmod +x /usr/local/sbin/certbotrenew.sh

# Exec script
sudo sh /usr/local/sbin/certbotrenew.sh

# Make crontab
sudo echo "0 8 1 * * /usr/local/sbin/certbotrenew.sh" >> /etc/crontab

# Patching
# git 
sudo cp /usr/local/openvpn_as/lib/python/pyovpn-2.0-py3.10.egg /usr/local/openvpn_as/lib/python/pyovpn-2.0-py3.10.egg_
sudo cp /usr/local/openvpn_as/lib/python/pyovpn-2.0-py3.10.egg /tmp/pyovpn-2.0-py3.10.egg
sudo systemctl stop openvpnas

# Information message
echo "*******************************************************************************************************************************"
sudo grep -A 1 -B 1 "Client" /usr/local/openvpn_as/init.log
echo "*******************************************************************************************************************************\n
****  !!!!!Auth on https://$ip_addr:943/admin  ********************************************************************************\n
****  !!!!!Be sure to replace the value with your own (domain):!!!!!!  ********************************************************\n
****  !!!!!'Admin  UI - Network Setting - Hostname to your previously specified domain:'!!!!!!  *******************************\n
*******************************************************************************************************************************\n
**** Download /tmp/pyovpn-2.0-py3.10.egg on your system and open with Winrar pyovpn-2.0-py3.10.egg  ***************************\n
**** Replace the file /pyovpn/lic/info.pyc with the one patched from the archive below    *************************************\n 
**** Patching in the archive 'data' | password: 'Orwell-1984'   ***************************************************************\n
**** Repalce original file /usr/local/openvpn_as/lib/python/pyovpn-2.0-py3.10.egg    ******************************************\n
*******************************************************************************************************************************"
