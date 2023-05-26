#!/usr/bin/env bash

USERNAME=$USER
echo "Setup docker for $USERNAME "

sudo apt update && sudo apt upgrade
sudo apt -y remove docker docker-engine docker.io containerd runc
sudo apt -y install --no-install-recommends apt-transport-https ca-certificates curl gnupg2
source /etc/os-release
curl -fsSL https://download.docker.com/linux/${ID}/gpg | sudo apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt -y install docker.io
sudo apt -y autoremove

echo "Add user $USER to docker group"
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

#echo "Create docker daemon config"
#sudo bash -c 'cat <<EOF >>/etc/docker/daemon.json
#{
#   "hosts": ["unix:///run/docker.sock", "tcp://0.0.0.0:2375"],
#   "features": {
#        "buildkit": true
#   }
#}
#EOF'
#
### allow user to start docker daemon without password
#echo "Allow user $USER to start docker daemon"
#DOCKER_DAEMON_PATH=$(which dockerd)
#sudo bash -c "echo \"$USER ALL = (root) NOPASSWD: $DOCKER_DAEMON_PATH *\" >> /etc/sudoers"

sudo bash -c 'cat <<EOF >>/lib/systemd/system/docker-tcp.socket
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=2375

BindIPv6Only=both
Service=docker.service

[Install]
WantedBy=sockets.target
EOF'

sudo systemctl daemon-reload
sudo systemctl stop docker.service
sudo systemctl enable docker-tcp.socket
sudo systemctl start docker-tcp.socket
sudo systemctl start docker.service

echo "Docker setup done"

echo "Check docker"
docker ps