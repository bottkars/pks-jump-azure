#!/usr/bin/env bash
source .env.sh
MYSELF=$(basename $0)
mkdir -p ${HOME_DIR}/logs
exec &> >(tee -a "${HOME_DIR}/logs/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1
sudo groupadd docker
sudo usermod -aG docker $ADMIN_USERNAME

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install docker-ce -y