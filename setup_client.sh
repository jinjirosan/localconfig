#!/bin/bash
# setup_client.sh
# This script prepares a fresh VM for remote Ansible management
# Run this script on the NEW VM (as root or with sudo privileges)
#
# Usage: ./setup_client.sh <control_host_ssh_public_key>
# Example: ./setup_client.sh "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."

set -e

# Configuration
ANSIBLE_USER="ansible"
CONTROL_HOST_SSH_KEY="${1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root or with sudo${NC}"
    exit 1
fi

# Check if SSH public key is provided
if [ -z "$CONTROL_HOST_SSH_KEY" ]; then
    echo -e "${RED}Error: SSH public key from control host is required${NC}"
    echo "Usage: $0 <control_host_ssh_public_key>"
    echo "Example: $0 \"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ...\""
    exit 1
fi

echo -e "${GREEN}Starting VM preparation for Ansible management...${NC}"

# Detect OS and set package manager
if [ -f /etc/debian_version ]; then
    PKG_MANAGER="apt"
    UPDATE_CMD="apt update"
    INSTALL_CMD="apt install -y"
    echo -e "${GREEN}Detected Debian/Ubuntu system${NC}"
elif [ -f /etc/redhat-release ]; then
    PKG_MANAGER="yum"
    UPDATE_CMD="yum check-update || true"
    INSTALL_CMD="yum install -y"
    echo -e "${GREEN}Detected RHEL/CentOS system${NC}"
else
    echo -e "${RED}Error: Unsupported OS. This script supports Debian/Ubuntu and RHEL/CentOS${NC}"
    exit 1
fi

# Update package lists
echo -e "${YELLOW}Updating package lists...${NC}"
eval "$UPDATE_CMD"

# Install required packages
echo -e "${YELLOW}Installing required packages (git, sudo, sshpass, python3)...${NC}"
if [ "$PKG_MANAGER" = "apt" ]; then
    $INSTALL_CMD git sudo sshpass python3 python3-pip
elif [ "$PKG_MANAGER" = "yum" ]; then
    # For RHEL, we might need EPEL for some packages
    if ! rpm -q epel-release > /dev/null 2>&1; then
        echo -e "${YELLOW}Installing EPEL repository...${NC}"
        $INSTALL_CMD epel-release || true
    fi
    $INSTALL_CMD git sudo sshpass python3 python3-pip
fi

# Verify Python3 is installed
if ! command -v python3 > /dev/null; then
    echo -e "${RED}Error: Python3 installation failed${NC}"
    exit 1
fi

# Create ansible user if it doesn't exist
if id "$ANSIBLE_USER" &>/dev/null; then
    echo -e "${YELLOW}User '$ANSIBLE_USER' already exists${NC}"
else
    echo -e "${YELLOW}Creating user '$ANSIBLE_USER'...${NC}"
    if [ "$PKG_MANAGER" = "apt" ]; then
        useradd -m -s /bin/bash "$ANSIBLE_USER"
    else
        useradd -m -s /bin/bash "$ANSIBLE_USER"
    fi
    echo -e "${GREEN}User '$ANSIBLE_USER' created successfully${NC}"
fi

# Create .ssh directory for ansible user
ANSIBLE_HOME=$(eval echo ~$ANSIBLE_USER)
SSH_DIR="$ANSIBLE_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

echo -e "${YELLOW}Setting up SSH directory for '$ANSIBLE_USER'...${NC}"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown "$ANSIBLE_USER:$ANSIBLE_USER" "$SSH_DIR"

# Add control host's SSH public key
echo -e "${YELLOW}Adding control host's SSH public key...${NC}"
if [ -f "$AUTHORIZED_KEYS" ]; then
    # Check if key already exists
    if grep -Fxq "$CONTROL_HOST_SSH_KEY" "$AUTHORIZED_KEYS" 2>/dev/null; then
        echo -e "${YELLOW}SSH key already exists in authorized_keys${NC}"
    else
        echo "$CONTROL_HOST_SSH_KEY" >> "$AUTHORIZED_KEYS"
        echo -e "${GREEN}SSH key added to authorized_keys${NC}"
    fi
else
    echo "$CONTROL_HOST_SSH_KEY" > "$AUTHORIZED_KEYS"
    echo -e "${GREEN}SSH key added to authorized_keys${NC}"
fi

chmod 600 "$AUTHORIZED_KEYS"
chown "$ANSIBLE_USER:$ANSIBLE_USER" "$AUTHORIZED_KEYS"

# Check if ansible user is already in sudoers
echo -e "${YELLOW}Configuring sudo access for '$ANSIBLE_USER'...${NC}"
SUDOERS_ENTRY="$ANSIBLE_USER ALL=(ALL:ALL) NOPASSWD:ALL"
if grep -Fxq "$SUDOERS_ENTRY" /etc/sudoers 2>/dev/null; then
    echo -e "${YELLOW}'$ANSIBLE_USER' is already in sudoers${NC}"
else
    # Add to sudoers using visudo for safety
    echo "$SUDOERS_ENTRY" | EDITOR='tee -a' visudo > /dev/null
    echo -e "${GREEN}'$ANSIBLE_USER' added to sudoers with NOPASSWD${NC}"
fi

# Display summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}VM Preparation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "  - User created: $ANSIBLE_USER"
echo "  - SSH key added: Yes"
echo "  - Sudo access: NOPASSWD configured"
echo "  - Required packages: Installed"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. On your control host, run: ./setup_remote.sh <this_vm_ip_or_hostname>"
echo "  2. The control host will deploy localconfig to this VM"
echo ""

