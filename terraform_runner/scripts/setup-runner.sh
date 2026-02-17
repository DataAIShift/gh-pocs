#!/bin/bash
set -e

# Parameters
GITHUB_REPO_URL=$1
RUNNER_TOKEN=$2
BASE_RUNNER_NAME=$3   # The base name (e.g., "my-runner")
RUNNER_LABELS=$4
ADMIN_USERNAME=$5

echo "Starting GitHub Multi-Runner setup (3 Instances)..."
echo "Repository: $GITHUB_REPO_URL"
echo "Base Runner Name: $BASE_RUNNER_NAME"

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

# Install required packages
echo "Installing required packages..."
sudo apt-get install -y \
    curl wget git jq unzip apt-transport-https \
    ca-certificates software-properties-common \
    gnupg lsb-release

# Upgrading system packages
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

# Install Ansible
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt-get update -y
sudo apt-get install -y ansible
sudo -u $ADMIN_USERNAME ansible-galaxy collection install ansible.windows community.windows azure.azcollection

# Install Github Cli
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update && sudo apt-get install gh -y

# Install PowerShell
wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update && sudo apt-get install -y powershell

# Install Azure PowerShell modules
sudo -u $ADMIN_USERNAME pwsh -c "Set-PSRepository -Name psgallery -InstallationPolicy Trusted; Install-Module -Name 'az.accounts', 'az.resources', 'az.storage', 'az.keyvault', 'pester' -Scope CurrentUser -Force"

# Install Packer
PACKER_VERSION="1.11.2" # Updated to a more recent stable version
wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
unzip packer_${PACKER_VERSION}_linux_amd64.zip
sudo mv packer /usr/local/bin/ && rm packer_${PACKER_VERSION}_linux_amd64.zip

# Install Terraform
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform -y

# --- RUNNER REGISTRATION LOOP ---

# Get latest runner version once
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
TEMP_TAR="/tmp/actions-runner.tar.gz"
curl -o $TEMP_TAR -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

for i in {1..3}
do
    RUNNER_NAME="${BASE_RUNNER_NAME}-${i}"
    RUNNER_HOME="/home/$ADMIN_USERNAME/actions-runner-${i}"

    echo "Setting up Runner #$i: $RUNNER_NAME"

    sudo mkdir -p $RUNNER_HOME
    sudo tar xzf $TEMP_TAR -C $RUNNER_HOME
    sudo chown -R $ADMIN_USERNAME:$ADMIN_USERNAME $RUNNER_HOME

    # Configure
    sudo -u $ADMIN_USERNAME bash -c "cd $RUNNER_HOME && ./config.sh --url $GITHUB_REPO_URL --token $RUNNER_TOKEN --name $RUNNER_NAME --labels $RUNNER_LABELS --unattended --replace"

    # Install as service
    cd $RUNNER_HOME
    sudo ./svc.sh install $ADMIN_USERNAME
    sudo ./svc.sh start
done

rm $TEMP_TAR
echo "All 3 Runners are online."