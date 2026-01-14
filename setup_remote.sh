#!/bin/bash
# setup_remote.sh
# This script deploys localconfig to a remote VM using Ansible
# Run this script on the CONTROL HOST (where localconfig repo is cloned)
#
# Usage: ./setup_remote.sh <remote_host_ip_or_hostname> [ansible_user] [target_user]
# Example: ./setup_remote.sh 172.16.234.7
# Example: ./setup_remote.sh 172.16.234.7 ansible
# Example: ./setup_remote.sh 172.16.234.7 ansible rayf

set -e

# Configuration
REMOTE_HOST="${1}"
ANSIBLE_USER="${2:-ansible}"
CONTROL_USER=$(whoami)
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
HOSTS_INI="hosts.ini"
TARGET_USER=""
PYTHON_INTERPRETER="/usr/bin/python3"  # Default, will be detected if SSH works

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if remote host is provided
if [ -z "$REMOTE_HOST" ]; then
    echo -e "${RED}Error: Remote host IP or hostname is required${NC}"
    echo "Usage: $0 <remote_host_ip_or_hostname> [ansible_user]"
    echo "Example: $0 172.16.234.7"
    echo "Example: $0 172.16.234.7 ansible"
    echo ""
    echo "  ansible_user: User to connect as (default: ansible)"
    echo ""
    echo "Note: You will be prompted to select which user(s) to configure."
    exit 1
fi

# Function to select target user configuration
select_target_user() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Target User Selection${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Please select which user(s) to configure with localconfig:"
    echo "  1) Ansible user and root only (default)"
    echo "  2) Specific user(s) - space-separated for multiple"
    echo "  3) All users on the system"
    echo ""
    read -p "Enter your choice [1-3] (default: 1): " choice
    choice=${choice:-1}
    
    case $choice in
        1)
            TARGET_USER="$ANSIBLE_USER"
            echo -e "${GREEN}Selected: Configure ansible user ($ANSIBLE_USER) and root${NC}"
            ;;
        2)
            echo ""
            echo -e "${YELLOW}Enter username(s) to configure (space-separated for multiple):${NC}"
            read -p "Username(s): " TARGET_USER
            if [ -z "$TARGET_USER" ]; then
                echo -e "${RED}Error: Username cannot be empty${NC}"
                exit 1
            fi
            # Count number of users (split by space)
            USER_COUNT=$(echo "$TARGET_USER" | wc -w | tr -d ' ')
            if [ "$USER_COUNT" -eq 1 ]; then
                echo -e "${GREEN}Selected: Configure user '$TARGET_USER'${NC}"
            else
                echo -e "${GREEN}Selected: Configure $USER_COUNT users: $TARGET_USER${NC}"
            fi
            ;;
        3)
            TARGET_USER="all"
            echo -e "${GREEN}Selected: Configure all users on the system${NC}"
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
}

# Select target user interactively
select_target_user

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

# Test SSH connectivity to remote host and detect OS
echo -e "${YELLOW}Testing SSH connectivity to $REMOTE_HOST...${NC}"
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$ANSIBLE_USER@$REMOTE_HOST" "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${GREEN}SSH connection successful${NC}"
    
    # Detect remote OS and set Python interpreter path
    echo -e "${YELLOW}Detecting remote OS...${NC}"
    REMOTE_OS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$ANSIBLE_USER@$REMOTE_HOST" \
        "if [ -f /etc/debian_version ]; then echo 'debian'; \
         elif [ -f /etc/redhat-release ]; then echo 'rhel'; \
         elif [ -f /etc/freebsd-update.conf ] || uname -s | grep -q FreeBSD; then echo 'freebsd'; \
         else echo 'unknown'; fi" 2>/dev/null)
    
    case "$REMOTE_OS" in
        freebsd)
            PYTHON_INTERPRETER="/usr/local/bin/python3"
            echo -e "${GREEN}Detected FreeBSD on remote host${NC}"
            ;;
        debian|rhel|unknown)
            PYTHON_INTERPRETER="/usr/bin/python3"
            if [ "$REMOTE_OS" = "debian" ]; then
                echo -e "${GREEN}Detected Debian/Ubuntu on remote host${NC}"
            elif [ "$REMOTE_OS" = "rhel" ]; then
                echo -e "${GREEN}Detected RHEL/CentOS on remote host${NC}"
            else
                echo -e "${YELLOW}Could not detect OS, using default Python path${NC}"
            fi
            ;;
    esac
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
    # Update the entry to ensure it has correct ansible_user and python interpreter
    if grep -q "^$REMOTE_HOST.*ansible_user=" "$HOSTS_INI"; then
        # Update existing entry
        sed -i.bak "s|^$REMOTE_HOST.*|$REMOTE_HOST ansible_user=$ANSIBLE_USER ansible_python_interpreter=$PYTHON_INTERPRETER|" "$HOSTS_INI"
    fi
else
    echo -e "${YELLOW}Adding $REMOTE_HOST to hosts.ini...${NC}"
    # Add to [remote] section
    if grep -q "^\[remote\]" "$HOSTS_INI"; then
        # Add after [remote] line
        sed -i.bak "/^\[remote\]/a\\
$REMOTE_HOST ansible_user=$ANSIBLE_USER ansible_python_interpreter=$PYTHON_INTERPRETER" "$HOSTS_INI"
    else
        # Add [remote] section and host
        cat >> "$HOSTS_INI" <<EOF

[remote]
$REMOTE_HOST ansible_user=$ANSIBLE_USER ansible_python_interpreter=$PYTHON_INTERPRETER
EOF
    fi
    echo -e "${GREEN}Remote host added to hosts.ini${NC}"
fi

# Remove backup file if it exists
[ -f "$HOSTS_INI.bak" ] && rm "$HOSTS_INI.bak"

# Verify hosts.ini entry
echo -e "${YELLOW}Verifying hosts.ini configuration...${NC}"
if grep -q "^$REMOTE_HOST.*ansible_user=$ANSIBLE_USER" "$HOSTS_INI"; then
    echo -e "${GREEN}Hosts.ini entry verified: $REMOTE_HOST with ansible_user=$ANSIBLE_USER${NC}"
else
    echo -e "${YELLOW}Warning: Could not verify hosts.ini entry. Current entry:${NC}"
    grep "^$REMOTE_HOST" "$HOSTS_INI" || echo "  (not found)"
fi

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

# Explicitly set the remote user to ensure it's used
# Note: No --ask-become-pass needed since setup_client.sh configures NOPASSWD sudo for ansible user
if [ "$TARGET_USER" = "all" ]; then
    ansible-playbook playbooks/site.yml -i "$HOSTS_INI" -l "$REMOTE_HOST" -u "$ANSIBLE_USER" --extra-vars "target_user=all"
else
    ansible-playbook playbooks/site.yml -i "$HOSTS_INI" -l "$REMOTE_HOST" -u "$ANSIBLE_USER" --extra-vars "target_user=$TARGET_USER"
fi

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Localconfig has been deployed to: $REMOTE_HOST"
    echo "Ansible user: $ANSIBLE_USER"
    if [ "$TARGET_USER" = "all" ]; then
        echo "Target users configured: All users on the system"
    else
        echo "Target user configured: $TARGET_USER (and root)"
    fi
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

