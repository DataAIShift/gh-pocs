#!/bin/bash
set -e

# Parameters
GITHUB_REPO_URL=$1
RUNNER_TOKEN=$2
RUNNER_NAME=$3
RUNNER_LABELS=$4
ADMIN_USERNAME=$5

echo "Starting GitHub Runner setup..."
echo "Repository: $GITHUB_REPO_URL"
echo "Runner Name: $RUNNER_NAME"
echo "Runner Labels: $RUNNER_LABELS"

# Update system
export DEBIAN_FRONTEND=noninteractive

# Wait for cloud-init and other startup processes to complete
echo "Waiting for cloud-init to complete..."
sudo cloud-init status --wait || true

# Wait for apt locks to be released
echo "Waiting for apt locks..."
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
    echo "Waiting for apt lock..."
    sleep 5
done

# Clean and update package lists
echo "Cleaning package cache..."
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get clean

echo "Updating package lists..."
sudo apt-get update -y

# Install required packages (without upgrade to avoid dpkg lock issues)
echo "Installing required packages..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    jq \
    unzip \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    gnupg \
    lsb-release

# Now upgrade system after essential packages are installed
echo "Upgrading system packages..."
sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $ADMIN_USERNAME

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install ansible
echo "Installing Ansible..."
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt-get update -y
sudo apt-get install -y ansible

echo "Installing Ansible Windows collections..."
ansible-galaxy collection install ansible.windows 
ansible-galaxy collection install community.windows
ansible-galaxy collection install azure.azcollection


echo "Verifying Ansible installation..."
ansible --version
ansible-galaxy collection list | grep ansible.windows

# Install Github Cli
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
&& chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& apt-get update \
&& apt-get install gh -y

# Install PowerShell
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb \
&& dpkg -i packages-microsoft-prod.deb \
&& apt-get update \
&& apt-get install -y --no-install-recommends powershell
pwsh --version

# install azure powershell modules required for azure powershell authentication to azure
echo "Installing Azure PowerShell modules..."
pwsh -c "Set-PSRepository -Name psgallery -InstallationPolicy Trusted; Install-Module -Name 'az.accounts', 'az.resources', 'az.storage', 'az.keyvault', 'pester' -Scope CurrentUser -Force"

# Install Packer
PACKER_VERSION="1.14.2"
wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
unzip packer_${PACKER_VERSION}_linux_amd64.zip
sudo mv packer /usr/local/bin/
rm packer_${PACKER_VERSION}_linux_amd64.zip

# install Terraform
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform -y

# install nodejs
#sudo apt install -y --no-install-recommends nodejs

# Create a directory for the runner
RUNNER_HOME="/home/$ADMIN_USERNAME/actions-runner"
sudo mkdir -p $RUNNER_HOME
sudo chown -R $ADMIN_USERNAME:$ADMIN_USERNAME $RUNNER_HOME
cd $RUNNER_HOME

# Download the latest runner package
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
echo "Downloading GitHub Runner version: $RUNNER_VERSION"
curl -o actions-runner-linux-x64.tar.gz -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

# Extract the installer
tar xzf actions-runner-linux-x64.tar.gz
rm actions-runner-linux-x64.tar.gz

# Configure the runner
sudo chown -R $ADMIN_USERNAME:$ADMIN_USERNAME $RUNNER_HOME
sudo -u $ADMIN_USERNAME bash -c "cd $RUNNER_HOME && ./config.sh --url $GITHUB_REPO_URL --token $RUNNER_TOKEN --name $RUNNER_NAME --labels $RUNNER_LABELS --unattended --replace"

# Install and start the runner as a service
cd $RUNNER_HOME
sudo ./svc.sh install $ADMIN_USERNAME
sudo ./svc.sh start

echo "GitHub Runner setup completed successfully!"
echo "Runner service status:"
sudo ./svc.sh status
 