#!/bin/bash

echo "Bootstrap script started..."

source /mnt/my_files/.env

# Docker installation
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo dpkg --configure -a
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo usermod -aG docker vagrant && newgrp docker

sudo systemctl enable docker
sudo systemctl start docker

# Minikube installation
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
su - vagrant -c "minikube start --cpus=2 --memory=2400 --nodes=1"


# Kubectl installation
KUBECTL_VERSION="v1.32.1"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Github runner instalation
mkdir actions-runner && cd actions-runner || exit
curl -o actions-runner-linux-x64-2.322.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-linux-x64-2.322.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.322.0.tar.gz

sudo chown -R vagrant:vagrant /home/vagrant/actions-runner
sudo chmod +x /home/vagrant/actions-runner/config.sh

su - vagrant -c "/home/vagrant/actions-runner/config.sh \
  --unattended \
  --url "$REPO_NAME" \
  --token "$RUNNER_TOKEN" \
  --name ubuntu-jammy \
  --work work \
  --labels self-hosted,Linux \
  --runnergroup default"

sudo chmod +x /home/vagrant/actions-runner/run.sh

cat <<EOF | sudo tee /etc/systemd/system/gh-runner.service
[Unit]
Description=Github Runner Process
After=network.target

[Service]
ExecStart=/home/vagrant/actions-runner/run.sh
Restart=always
User=vagrant
WorkingDirectory=/home/vagrant
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable gh-runner.service
sudo systemctl start gh-runner.service

echo "VM has been configured!"
