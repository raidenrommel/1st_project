#!/bin/bash

# =============================
# System Update and Cleanup
# =============================

echo "Configuring system for non-interactive updates..."

# Suppress prompts for restarting services automatically
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
echo 'APT::Install-Recommends "false";' | sudo tee /etc/apt/apt.conf.d/99norecommends
echo 'DPkg::Options {
    "--force-confdef";
    "--force-confold";
}' | sudo tee /etc/apt/apt.conf.d/70debconf
echo 'System::NoPrompt "true";' | sudo tee /etc/apt/apt.conf.d/99noprogress

echo "Updating system..."
# Run the update and upgrade commands in non-interactive mode
sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y --option Dpkg::Options::="--force-confdef" --option Dpkg::Options::="--force-confold"

echo "Cleaning up unnecessary packages..."
# Remove unnecessary packages
sudo apt autoremove -y
sudo apt autoclean -y

echo "System update and cleanup completed successfully!"

# Restart necessary services
echo "Restarting necessary services..."
sudo systemctl restart networkd-dispatcher.service
sudo systemctl restart unattended-upgrades.service
echo "System services restarted successfully!"

# =============================
# Java Installation (Java 17)
# =============================

if ! java -version 2>&1 | grep -q "openjdk version 17"; then
    echo "Installing Java 17..."
    sudo apt update -y
    sudo apt install -y openjdk-17-jdk
    sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java

    echo "Verifying Java installation..."
    java -version
    echo "Java 17 installed and set as default successfully!"
else
    echo "Java 17 is already installed, skipping installation."
    java -version
fi

# =============================
# Docker Installation
# =============================

if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt update -y
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update -y && sudo apt install -y docker-ce docker-ce-cli containerd.io

    sudo systemctl enable --now docker
    echo "Docker installation completed successfully!"
else
    echo "Docker is already installed, skipping installation."
fi

echo "Verifying Docker installation..."
docker --version

set -e

# =============================
# Jenkins Installation
# =============================

echo "Starting Jenkins installation and configuration..."

# Check if Jenkins is already installed
if ! command -v jenkins &> /dev/null; then
    echo "Installing Jenkins..."

    # Add Jenkins GPG key
    echo "Adding Jenkins GPG key..."
    curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee \
    /usr/share/keyrings/jenkins-keyring.asc > /dev/null

    # Add Jenkins repository
    echo "Adding Jenkins repository..."
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    # Update package list and install Jenkins and OpenJDK
    echo "Updating package list and installing Jenkins and OpenJDK..."
    sudo apt update -y
    sudo apt install -y openjdk-11-jdk jenkins

    echo "Jenkins installation completed successfully!"
else
    echo "Jenkins is already installed, skipping installation."
fi

# =============================
# Jenkins ExecStart Override
# =============================

echo "Updating Jenkins ExecStart and configuring port 8450..."

# Define the override configuration directory and file
SERVICE_OVERRIDE_DIR="/etc/systemd/system/jenkins.service.d"
SERVICE_OVERRIDE_FILE="${SERVICE_OVERRIDE_DIR}/override.conf"

# Create the override configuration directory if it doesn't exist
if [ ! -d "$SERVICE_OVERRIDE_DIR" ]; then
    echo "Creating override directory: $SERVICE_OVERRIDE_DIR"
    sudo mkdir -p "$SERVICE_OVERRIDE_DIR"
fi

# Add the ExecStart lines to the override configuration file
sudo bash -c "cat > $SERVICE_OVERRIDE_FILE <<EOL
[Service]
ExecStart=
ExecStart=/usr/bin/java -Djava.awt.headless=true -jar /usr/share/java/jenkins.war --webroot=/var/cache/jenkins/war --httpPort=8450
EOL"

# =============================
# Reload and Restart Jenkins
# =============================

# Reload systemd configuration to apply changes
echo "Reloading systemd configuration..."
sudo systemctl daemon-reload

# Restart Jenkins service
echo "Restarting Jenkins service..."
sudo systemctl restart jenkins

# Enable Jenkins service on boot
sudo systemctl enable jenkins

# =============================
# Verify Jenkins Status
# =============================

echo "Verifying Jenkins status..."
if sudo lsof -i :8450 > /dev/null 2>&1; then
    echo "Success: Jenkins is running on port 8450."
else
    echo "Error: Jenkins is not running on port 8450. Please check the logs for more details."
    exit 1
fi

echo "Jenkins installation and configuration completed successfully!"






# =============================
# Node.js, npm, and PM2 Installation
# =============================

echo "Installing Node.js, npm, and PM2..."
sudo apt update -y
sudo apt install -y curl software-properties-common
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

echo "Verifying Node.js and npm installation..."
node -v
npm -v

echo "Installing PM2..."
sudo npm install -g pm2
pm2 -v

sudo pm2 startup -u $USER --hp $HOME

# Create app.js in the correct location
APP_PATH="/home/rommel/app.js"
echo "console.log('Hello, PM2!'); setInterval(() => console.log('PM2 running...'), 5000);" > $APP_PATH

# Ensure the file is created before proceeding
if [ -f "$APP_PATH" ]; then
    echo "Starting PM2 process for app.js..."
    pm2 start "$APP_PATH" --name example-app
    pm2 save
else
    echo "Error: app.js file was not created at $APP_PATH. Please check permissions or disk space."
    exit 1
fi

# Escape bash history expansion in commands
echo "Freezing PM2 process list for reboot..."
pm2 save --force

# =============================
# Additional Tools Installation
# =============================

echo "Ensuring Bash is installed..."
sudo apt install -y bash
bash --version

echo "Installing Tree..."
sudo apt install -y tree
tree --version

echo "Installing Wget..."
sudo apt install -y wget
wget --version

echo "Installing Git..."
sudo apt install -y git
git --version

echo "Installing Python3 and pip3..."
sudo apt install -y python3 python3-pip
python3 --version
pip3 --version

# =============================
# Verify Installed Package Versions
# =============================

echo "======================================================"
echo "Verifying installed package versions..."
echo "======================================================"

# Node.js and npm
echo "Node.js version:"
node -v

echo "npm version:"
npm -v

# PM2
echo "PM2 version:"
pm2 -v

# Java
echo "Java version:"
java -version

# Docker
echo "Docker version:"
docker --version

# Jenkins
echo "Jenkins version:"
curl -s http://localhost:8450/api/json?pretty=true | grep '"version"' || echo "Jenkins is not running or unreachable"

# Bash
echo "Bash version:"
bash --version | head -n 1

# Tree
echo "Tree version:"
tree --version

# Wget
echo "Wget version:"
wget --version | head -n 1

# Git
echo "Git version:"
git --version

# Python3 and pip3
echo "Python3 version:"
python3 --version

echo "pip3 version:"
pip3 --version

echo "======================================================"
echo "All package versions verified successfully!"




# =============================
# jenkins post installation
# =============================



echo "======================================================"
echo     "Make jenkins root user paswordless and sudoer"
echo "======================================================"



# Step 1: Add jenkins user to sudoers for passwordless sudo
echo "Adding jenkins user to sudoers for passwordless sudo..."
echo "jenkins ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null

# Step 2: Switch to jenkins user
echo "Switching to jenkins user..."
sudo su - jenkins -c "whoami"

# Step 3: Modify the Jenkins service file to run as root
echo "Modifying Jenkins service file to run as root..."

# Create a backup of the original service file
sudo cp /lib/systemd/system/jenkins.service /lib/systemd/system/jenkins.service.bak

# Modify the User and Group to root
sudo sed -i 's/^User=jenkins/User=root/' /lib/systemd/system/jenkins.service
sudo sed -i 's/^Group=jenkins/Group=root/' /lib/systemd/system/jenkins.service

# Step 4: Reload systemd and restart Jenkins service
echo "Reloading systemd and restarting Jenkins service..."
sudo systemctl daemon-reload
sudo systemctl restart jenkins

# Step 5: Verify Jenkins is running as root
echo "Verifying Jenkins service is running as root..."
ps aux | grep jenkins

echo "Script execution completed!"