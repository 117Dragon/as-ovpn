# Create or reset the openvpn administrative local account with specified password

echo "Enter new password for user 'openvpn"
read -s PASSWORD

cd /usr/local/openvpn_as/scripts
./sacli --user "openvpn" --key "prop_superuser" --value "true" UserPropPut
./sacli --user "openvpn" --key "user_auth_type" --value "local" UserPropPut
./sacli --user "openvpn" --new_pass=$PASSWORD SetLocalPassword
./sacli start

# End of
read -n 1 -s -r -p "----Press 'any key'----"
