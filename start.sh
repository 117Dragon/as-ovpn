#!/bin/bash

sudo apt update && sudo apt install git -y
git clone https://github.com/117Dragon/as-ovpn.git
cd as-ovpn
sudo sh ./scripts/install_dependencies.sh
