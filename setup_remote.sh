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
ADDITIONAL_SUDO_USERS=""
REPLACE_MOTD="no"  # Default to no, will be set by preview_motd function
PYTHON_INTERPRETER="/usr/bin/python3"  # Default, will be detected if SSH works
# security_setup role defaults (must match roles/security_setup/defaults/main.yml)
SECURITY_SSH_ALLOWED_DEFAULT="172.16.233.0/26 172.16.234.0/26"
SECURITY_DNS_SERVERS_DEFAULT="172.16.234.16 172.16.234.26"
SECURITY_SETUP_ENABLED="false"
SECURITY_SSH_ALLOWED="$SECURITY_SSH_ALLOWED_DEFAULT"
SECURITY_DNS_SERVERS="$SECURITY_DNS_SERVERS_DEFAULT"
DESKTOP_APPS_ENABLED="false"

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

# Function to select additional users for passwordless sudo
select_additional_sudo_users() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Additional Sudo Users${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Which additional users should be added to passwordless sudo?"
    echo ""
    if [ "$TARGET_USER" = "all" ]; then
        echo -e "${YELLOW}Note: You selected 'All users' above.${NC}"
        echo -e "${YELLOW}All users in /home/ will already get localconfig dotfiles and sudo access.${NC}"
        echo -e "${YELLOW}Additional users listed here will only get sudo access (if not already covered).${NC}"
    else
        echo -e "${YELLOW}Note: These users will get NOPASSWD sudo access but will NOT get localconfig dotfiles${NC}"
        echo -e "${YELLOW}unless you selected option 3 (All users) in the previous question.${NC}"
        echo ""
        echo -e "${YELLOW}The target user(s) you selected above will already get both sudo access and dotfiles.${NC}"
    fi
    echo ""
    read -p "Enter username(s) (space-separated) or press Enter to skip: " ADDITIONAL_SUDO_USERS
    ADDITIONAL_SUDO_USERS=${ADDITIONAL_SUDO_USERS:-""}
    
    if [ -n "$ADDITIONAL_SUDO_USERS" ]; then
        # Count number of users (split by space)
        SUDO_USER_COUNT=$(echo "$ADDITIONAL_SUDO_USERS" | wc -w | tr -d ' ')
        if [ "$SUDO_USER_COUNT" -eq 1 ]; then
            echo -e "${GREEN}Will add '$ADDITIONAL_SUDO_USERS' to passwordless sudo${NC}"
        else
            echo -e "${GREEN}Will add $SUDO_USER_COUNT users to passwordless sudo: $ADDITIONAL_SUDO_USERS${NC}"
        fi
    else
        echo -e "${YELLOW}No additional users will be added to sudoers${NC}"
    fi
}

# Function to preview MOTD and ask for replacement confirmation
preview_motd() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}MOTD Preview and Replacement${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Use the already detected REMOTE_OS variable
    # Set MOTD file path based on OS
    if [ "$REMOTE_OS" = "freebsd" ]; then
        MOTD_FILE="/etc/motd.template"
    elif [ "$REMOTE_OS" = "rhel" ]; then
        MOTD_FILE="/etc/issue"
    else
        MOTD_FILE="/etc/motd"
    fi
    
    # Get current MOTD content
    echo -e "${YELLOW}Current MOTD content from $MOTD_FILE:${NC}"
    echo ""
    CURRENT_MOTD=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PreferredAuthentications=publickey "$ANSIBLE_USER@$REMOTE_HOST" "cat $MOTD_FILE 2>/dev/null || echo '(File does not exist or is empty)'")
    echo -e "${YELLOW}$CURRENT_MOTD${NC}"
    echo ""
    echo -e "${YELLOW}The new MOTD will contain ASCII art of the hostname and system information.${NC}"
    echo ""
    read -p "Do you want to replace the current MOTD with the new one? [y/N]: " replace_motd
    replace_motd=${replace_motd:-N}
    
    case $replace_motd in
        [Yy]*)
            REPLACE_MOTD="yes"
            echo -e "${GREEN}MOTD will be replaced with the new generated one${NC}"
            ;;
        *)
            REPLACE_MOTD="no"
            echo -e "${YELLOW}MOTD will be skipped (keeping current content)${NC}"
            ;;
    esac
}

# Function to ask security_setup (firewall) options
ask_security_setup() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Firewall (security_setup role)${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    read -p "Enable firewall (security_setup role)? [y/N]: " enable_fw
    enable_fw=${enable_fw:-N}
    case $enable_fw in
        [Yy]*)
            SECURITY_SETUP_ENABLED="true"
            echo -e "${GREEN}Firewall will be configured${NC}"
            ;;
        *)
            SECURITY_SETUP_ENABLED="false"
            SECURITY_SSH_ALLOWED="$SECURITY_SSH_ALLOWED_DEFAULT"
            SECURITY_DNS_SERVERS="$SECURITY_DNS_SERVERS_DEFAULT"
            echo -e "${YELLOW}Firewall will be skipped${NC}"
            return
            ;;
    esac

    echo ""
    echo "SSH allowed source ranges (CIDR). These subnets can connect to SSH on the target."
    echo "  Default: $SECURITY_SSH_ALLOWED_DEFAULT"
    echo "  1) Use defaults (recommended)"
    echo "  2) Enter custom ranges (space-separated, e.g. 172.16.233.0/26 10.0.0.0/24)"
    echo ""
    read -p "Enter your choice [1-2] (default: 1): " ssh_choice
    ssh_choice=${ssh_choice:-1}
    case $ssh_choice in
        2)
            read -p "Enter CIDR ranges (space-separated): " SECURITY_SSH_ALLOWED
            if [ -z "$SECURITY_SSH_ALLOWED" ]; then
                echo -e "${YELLOW}Empty input, using defaults${NC}"
                SECURITY_SSH_ALLOWED="$SECURITY_SSH_ALLOWED_DEFAULT"
            else
                echo -e "${GREEN}Using custom SSH ranges: $SECURITY_SSH_ALLOWED${NC}"
            fi
            ;;
        *)
            SECURITY_SSH_ALLOWED="$SECURITY_SSH_ALLOWED_DEFAULT"
            echo -e "${GREEN}Using default SSH ranges${NC}"
            ;;
    esac

    echo ""
    echo "DNS servers for firewall outbound allow list."
    echo "  Current defaults: $SECURITY_DNS_SERVERS_DEFAULT"
    echo "  1) Use defaults"
    echo "  2) Enter custom DNS server IPs (space-separated)"
    echo ""
    read -p "Enter your choice [1-2] (default: 1): " dns_choice
    dns_choice=${dns_choice:-1}
    case $dns_choice in
        2)
            read -p "Enter DNS server IPs (space-separated): " SECURITY_DNS_SERVERS
            if [ -z "$SECURITY_DNS_SERVERS" ]; then
                echo -e "${YELLOW}Empty input, using defaults${NC}"
                SECURITY_DNS_SERVERS="$SECURITY_DNS_SERVERS_DEFAULT"
            else
                echo -e "${GREEN}Using custom DNS servers: $SECURITY_DNS_SERVERS${NC}"
            fi
            ;;
        *)
            SECURITY_DNS_SERVERS="$SECURITY_DNS_SERVERS_DEFAULT"
            echo -e "${GREEN}Using default DNS servers${NC}"
            ;;
    esac
}

# Function to ask desktop apps setup
ask_desktop_apps_setup() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Desktop Applications Setup${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    read -p "Enable desktop applications setup? [y/N]: " enable_desktop_apps
    enable_desktop_apps=${enable_desktop_apps:-N}
    case $enable_desktop_apps in
        [Yy]*)
            DESKTOP_APPS_ENABLED="true"
            echo -e "${GREEN}Desktop applications setup will be configured${NC}"
            echo -e "${YELLOW}You will be prompted for each application during playbook execution${NC}"
            ;;
        *)
            DESKTOP_APPS_ENABLED="false"
            echo -e "${YELLOW}Desktop applications setup will be skipped${NC}"
            ;;
    esac
}

# Select target user interactively
select_target_user

# Select additional sudo users
select_additional_sudo_users

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
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PreferredAuthentications=publickey "$ANSIBLE_USER@$REMOTE_HOST" "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${GREEN}SSH connection successful${NC}"
    
    # Detect remote OS and set Python interpreter path
    echo -e "${YELLOW}Detecting remote OS...${NC}"
    REMOTE_OS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PreferredAuthentications=publickey "$ANSIBLE_USER@$REMOTE_HOST" \
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
    
    # Preview MOTD and ask for replacement (after SSH connectivity is confirmed)
    preview_motd

    # Ask security_setup (firewall) options
    ask_security_setup

    # Ask desktop apps setup
    ask_desktop_apps_setup
else
    echo -e "${RED}Error: Cannot connect to $REMOTE_HOST as $ANSIBLE_USER using SSH key authentication${NC}"
    echo ""
    echo -e "${YELLOW}This usually means the SSH key mismatch between setup_client.sh and setup_remote.sh${NC}"
    echo ""
    echo "Diagnostics:"
    echo "  - Control host SSH public key: $SSH_KEY_PATH"
    echo "  - Key fingerprint: $(ssh-keygen -lf "$SSH_KEY_PATH" 2>/dev/null | awk '{print $2}' || echo 'N/A')"
    echo ""
    echo -e "${YELLOW}Root Cause:${NC}"
    echo "  setup_client.sh may have used a hardcoded default key (option 1)"
    echo "  that doesn't match your control host's actual key at $SSH_KEY_PATH"
    echo ""
    echo -e "${GREEN}Quick Fix - Run this on the remote VM:${NC}"
    echo "  ./setup_client.sh \"$SSH_PUBLIC_KEY\""
    echo ""
    echo -e "${GREEN}Or manually add the key (as root on remote VM):${NC}"
    echo "  echo \"$SSH_PUBLIC_KEY\" >> ~ansible/.ssh/authorized_keys"
    echo "  chmod 600 ~ansible/.ssh/authorized_keys"
    echo "  chown ansible:ansible ~ansible/.ssh/authorized_keys"
    echo ""
    echo -e "${YELLOW}To prevent this in the future:${NC}"
    echo "  When running setup_client.sh, choose option 2 and paste the key from:"
    echo "  cat $SSH_KEY_PATH"
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
    ansible-playbook playbooks/site.yml -i "$HOSTS_INI" -l "$REMOTE_HOST" -u "$ANSIBLE_USER" --extra-vars "target_user=all replace_motd=$REPLACE_MOTD additional_sudo_users='$ADDITIONAL_SUDO_USERS' security_setup_enabled=$SECURITY_SETUP_ENABLED security_ssh_allowed_networks='$SECURITY_SSH_ALLOWED' security_dns_servers='$SECURITY_DNS_SERVERS' desktop_apps_enabled=$DESKTOP_APPS_ENABLED"
else
    ansible-playbook playbooks/site.yml -i "$HOSTS_INI" -l "$REMOTE_HOST" -u "$ANSIBLE_USER" --extra-vars "target_user=$TARGET_USER replace_motd=$REPLACE_MOTD additional_sudo_users='$ADDITIONAL_SUDO_USERS' security_setup_enabled=$SECURITY_SETUP_ENABLED security_ssh_allowed_networks='$SECURITY_SSH_ALLOWED' security_dns_servers='$SECURITY_DNS_SERVERS' desktop_apps_enabled=$DESKTOP_APPS_ENABLED"
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

