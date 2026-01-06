#!/bin/bash
# setup_remote.sh
# This script deploys localconfig to a remote VM using Ansible
# Run this script on the CONTROL HOST (where localconfig repo is cloned)
#
# Usage: ./setup_remote.sh <remote_host_ip_or_hostname> [ansible_user]
# Example: ./setup_remote.sh 172.16.234.7
# Example: ./setup_remote.sh 172.16.234.7 ansible

set -e

# Configuration
REMOTE_HOST="${1}"
ANSIBLE_USER="${2:-ansible}"
CONTROL_USER=$(whoami)
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
HOSTS_INI="hosts.ini"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if remote host is provided
if [ -z "$REMOTE_HOST" ]; then
    echo -e "${RED}Error: Remote host IP or hostname is required${NC}"
    echo "Usage: $0 <remote_host_ip_or_hostname> [ansible_user]"
    echo "Example: $0 172.16.234.7"
    echo "Example: $0 172.16.234.7 ansible"
    exit 1
fi

echo -e "${GREEN}Preparing to deploy localconfig to remote host: $REMOTE_HOST${NC}"

# Navigate to script directory (localconfig repo root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit

# Check if we're in the localconfig repository
if [ ! -f "playbooks/site.yml" ] || [ ! -d "roles" ]; then
    echo -e "${RED}Error: This script must be run from the localconfig repository root${NC}"
    exit 1
fi

# Check if Ansible is installed
if ! command -v ansible > /dev/null; then
    echo -e "${RED}Error: Ansible is not installed${NC}"
    echo "Please install Ansible first:"
    echo "  Debian/Ubuntu: sudo apt install ansible"
    echo "  RHEL/CentOS: sudo yum install epel-release && sudo yum install ansible"
    exit 1
fi

# Check if SSH public key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${YELLOW}SSH public key not found at $SSH_KEY_PATH${NC}"
    echo -e "${YELLOW}Generating SSH key pair...${NC}"
    ssh-keygen -t rsa -b 2048 -f "$HOME/.ssh/id_rsa" -N "" -q
    echo -e "${GREEN}SSH key pair generated${NC}"
fi

# Read SSH public key
SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH")
echo -e "${GREEN}Using SSH public key from: $SSH_KEY_PATH${NC}"

# Test SSH connectivity to remote host
echo -e "${YELLOW}Testing SSH connectivity to $REMOTE_HOST...${NC}"
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$ANSIBLE_USER@$REMOTE_HOST" "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${GREEN}SSH connection successful${NC}"
else
    echo -e "${RED}Error: Cannot connect to $REMOTE_HOST as $ANSIBLE_USER${NC}"
    echo ""
    echo "Please ensure:"
    echo "  1. You have run setup_client.sh on the remote VM"
    echo "  2. The remote VM is accessible from this host"
    echo "  3. The SSH key has been added to the remote VM"
    echo ""
    echo "To prepare the remote VM, copy setup_client.sh to it and run:"
    echo "  ./setup_client.sh \"$SSH_PUBLIC_KEY\""
    exit 1
fi

# Ensure hosts.ini exists
if [ ! -f "$HOSTS_INI" ]; then
    echo -e "${YELLOW}Creating hosts.ini file...${NC}"
    cat > "$HOSTS_INI" <<EOF
[local]
localhost ansible_connection=local ansible_user=root ansible_become=yes ansible_python_interpreter=/usr/bin/python3

[remote]
# Remote hosts will be added here
EOF
fi

# Check if remote host already exists in hosts.ini
if grep -q "^$REMOTE_HOST" "$HOSTS_INI" 2>/dev/null; then
    echo -e "${YELLOW}Remote host $REMOTE_HOST already exists in hosts.ini${NC}"
    # Update the entry to ensure it has correct ansible_user
    if grep -q "^$REMOTE_HOST.*ansible_user=" "$HOSTS_INI"; then
        # Update existing entry
        sed -i.bak "s|^$REMOTE_HOST.*|$REMOTE_HOST ansible_user=$ANSIBLE_USER ansible_python_interpreter=/usr/bin/python3|" "$HOSTS_INI"
    fi
else
    echo -e "${YELLOW}Adding $REMOTE_HOST to hosts.ini...${NC}"
    # Add to [remote] section
    if grep -q "^\[remote\]" "$HOSTS_INI"; then
        # Add after [remote] line
        sed -i.bak "/^\[remote\]/a\\
$REMOTE_HOST ansible_user=$ANSIBLE_USER ansible_python_interpreter=/usr/bin/python3" "$HOSTS_INI"
    else
        # Add [remote] section and host
        cat >> "$HOSTS_INI" <<EOF

[remote]
$REMOTE_HOST ansible_user=$ANSIBLE_USER ansible_python_interpreter=/usr/bin/python3
EOF
    fi
    echo -e "${GREEN}Remote host added to hosts.ini${NC}"
fi

# Remove backup file if it exists
[ -f "$HOSTS_INI.bak" ] && rm "$HOSTS_INI.bak"

# Test Ansible connectivity
echo -e "${YELLOW}Testing Ansible connectivity...${NC}"
if ansible "$REMOTE_HOST" -i "$HOSTS_INI" -m ping -u "$ANSIBLE_USER" > /dev/null 2>&1; then
    echo -e "${GREEN}Ansible connectivity test successful${NC}"
else
    echo -e "${RED}Error: Ansible connectivity test failed${NC}"
    echo "Please check:"
    echo "  1. SSH key authentication is working"
    echo "  2. The ansible user has sudo access"
    echo "  3. Python3 is installed on the remote host"
    exit 1
fi

# Run the Ansible playbook
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying localconfig to $REMOTE_HOST${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

ansible-playbook playbooks/site.yml -i "$HOSTS_INI" -l "$REMOTE_HOST" --ask-become-pass

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Localconfig has been deployed to: $REMOTE_HOST"
    echo "User: $ANSIBLE_USER"
    echo ""
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Deployment failed!${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "Please check the error messages above for details."
    exit 1
fi

