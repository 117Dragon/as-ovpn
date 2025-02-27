#!/bin/bash

sudo apt update && sudo apt install git -y
cd /tmp/
git clone https://github.com/117Dragon/as.git
sudo bash ./as/scripts/install_dependencies.sh
