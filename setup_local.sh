#!/bin/bash
# setup_local.sh
# This script deploys localconfig to the local machine using Ansible
# Run this script on the LOCAL MACHINE (where localconfig repo is cloned)
#
# Usage: ./setup_local.sh

set -e

# Get the currently logged-in user
CURRENT_USER=$(whoami)
TARGET_USER=""
ADDITIONAL_SUDO_USERS=""
REPLACE_MOTD="no"  # Default to no
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

# Function to select target user configuration
select_target_user() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Target User Selection${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Please select which user(s) to configure with localconfig:"
    echo "  1) Current user ($CURRENT_USER) and root only (default)"
    echo "  2) Specific user(s) - space-separated for multiple"
    echo "  3) All users on the system"
    echo ""
    read -p "Enter your choice [1-3] (default: 1): " choice
    choice=${choice:-1}
    
    case $choice in
        1)
            TARGET_USER="$CURRENT_USER"
            echo -e "${GREEN}Selected: Configure current user ($CURRENT_USER) and root${NC}"
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

echo -e "${GREEN}Preparing to deploy localconfig to local machine...${NC}"

# Navigate to script directory (localconfig repo root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit

# Check if we're in the localconfig repository
if [ ! -f "playbooks/site.yml" ] || [ ! -d "roles" ]; then
    echo -e "${RED}Error: This script must be run from the localconfig repository root${NC}"
    exit 1
fi

# Detect OS for Ansible installation and Python path
if [ -f /etc/debian_version ]; then
    OS_TYPE="debian"
    PYTHON_INTERPRETER="/usr/bin/python3"
elif [ -f /etc/redhat-release ]; then
    OS_TYPE="rhel"
    PYTHON_INTERPRETER="/usr/bin/python3"
elif [ -f /etc/freebsd-update.conf ] || uname -s | grep -q FreeBSD; then
    OS_TYPE="freebsd"
    PYTHON_INTERPRETER="/usr/local/bin/python3"
else
    OS_TYPE="unknown"
    PYTHON_INTERPRETER="/usr/bin/python3"
fi

# Verify Python interpreter exists, try to find it if default path doesn't work
if [ ! -f "$PYTHON_INTERPRETER" ]; then
    PYTHON_INTERPRETER=$(command -v python3 2>/dev/null || echo "$PYTHON_INTERPRETER")
fi

# Ensure Ansible is installed
if ! command -v ansible > /dev/null; then
    echo -e "${YELLOW}Ansible is not installed. Installing Ansible...${NC}"
    if [ "$OS_TYPE" = "debian" ]; then
        sudo apt update && sudo apt install ansible -y
    elif [ "$OS_TYPE" = "rhel" ]; then
        sudo yum install epel-release -y && sudo yum install ansible -y
    elif [ "$OS_TYPE" = "freebsd" ]; then
        sudo pkg install -y ansible
    else
        echo -e "${RED}Unsupported OS. Please install Ansible manually.${NC}"
        exit 1
    fi
fi

# Select target user interactively
select_target_user

# Select additional sudo users
select_additional_sudo_users

# Ask security_setup (firewall) options
ask_security_setup

# Ask desktop apps setup
ask_desktop_apps_setup

# Ensure hosts.ini exists and is correctly configured
if [ ! -f hosts.ini ]; then
    echo -e "${YELLOW}Creating hosts.ini file...${NC}"
    cat > hosts.ini <<EOF
[local]
localhost ansible_connection=local ansible_user=$CURRENT_USER ansible_become=yes ansible_python_interpreter=$PYTHON_INTERPRETER
EOF
    echo -e "${GREEN}Generated hosts.ini with a [local] section.${NC}"
else
    # Update hosts.ini to ensure it has correct ansible_user and python interpreter
    if ! grep -q "^localhost.*ansible_user=" hosts.ini 2>/dev/null; then
        echo -e "${YELLOW}Updating hosts.ini with current user and Python interpreter...${NC}"
        sed -i.bak "s|^localhost.*|localhost ansible_connection=local ansible_user=$CURRENT_USER ansible_become=yes ansible_python_interpreter=$PYTHON_INTERPRETER|" hosts.ini
        [ -f hosts.ini.bak ] && rm hosts.ini.bak
    fi
fi

# Check if the current user is already in sudoers with NOPASSWD
NEED_BECOME_PASS=""
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}Current user ($CURRENT_USER) requires password for sudo.${NC}"
    echo -e "${YELLOW}You will be prompted for your sudo password.${NC}"
    NEED_BECOME_PASS="--ask-become-pass"
else
    echo -e "${GREEN}Current user ($CURRENT_USER) has passwordless sudo access.${NC}"
fi

# Run the Ansible playbook
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying localconfig to local machine${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Always pass target_user explicitly (ansible_user comes from hosts.ini)
if [ "$TARGET_USER" = "all" ]; then
    ansible-playbook playbooks/site.yml -i hosts.ini -l local --extra-vars "target_user=all replace_motd=$REPLACE_MOTD additional_sudo_users='$ADDITIONAL_SUDO_USERS' security_setup_enabled=$SECURITY_SETUP_ENABLED security_ssh_allowed_networks='$SECURITY_SSH_ALLOWED' security_dns_servers='$SECURITY_DNS_SERVERS' desktop_apps_enabled=$DESKTOP_APPS_ENABLED" $NEED_BECOME_PASS
else
    ansible-playbook playbooks/site.yml -i hosts.ini -l local --extra-vars "target_user=$TARGET_USER replace_motd=$REPLACE_MOTD additional_sudo_users='$ADDITIONAL_SUDO_USERS' security_setup_enabled=$SECURITY_SETUP_ENABLED security_ssh_allowed_networks='$SECURITY_SSH_ALLOWED' security_dns_servers='$SECURITY_DNS_SERVERS' desktop_apps_enabled=$DESKTOP_APPS_ENABLED" $NEED_BECOME_PASS
fi

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Local setup completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Localconfig has been deployed to: localhost"
    echo "Ansible user: $CURRENT_USER"
    if [ "$TARGET_USER" = "all" ]; then
        echo "Target users configured: All users on the system"
    else
        echo "Target user configured: $TARGET_USER (and root)"
    fi
    echo ""
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Local setup failed!${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "Please check the error messages above for details."
    exit 1
fi
