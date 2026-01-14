#!/bin/sh
# setup_client.sh
# This script prepares a fresh VM for remote Ansible management
# Run this script on the NEW VM (as root or with sudo privileges)
#
# Usage: ./setup_client.sh
#       or ./setup_client.sh <control_host_ssh_public_key> (non-interactive mode)
#
# Note: This script is POSIX-compliant and works with /bin/sh on FreeBSD and Raspberry Pi

set -e

# Configuration
ANSIBLE_USER="ansible"
DEFAULT_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4NVd3hCHLQZxBq9icE547vv1CCbACXQDyKZj09iAcobtAvT7U0jy4PcfmdKtWJA8u/2axYDSs9VbjdJi+crJn7oc0GC6/Jt9hF+u7Ok4jLfnMnNxB/3jzJJlnwLz8JHvZd7AGv4++yWHd+3mEIrYZAXNaszfhs4cgwmfWK1QTHGM566/SrV/GUqGxiaVjDNQ9MpyY6v0gpURAqhVAP7pyM3kKIDugMrPHHVk71WrHoqRmH8XJBlZfwykIxEQPYRmKuggxedIru80Fa4rZ4oV9UgauVouaQFJvpEca4n1+92J+JTbTJRoFrOaOERggtTbpXu4nYOIPFnX6Wn9a1nnZ"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root or with sudo (POSIX-compliant)
if [ "$(id -u)" -ne 0 ]; then
    printf "%b\n" "${RED}Error: This script must be run as root or with sudo${NC}"
    exit 1
fi

# Function to get SSH public key (interactive or from argument)
get_ssh_key() {
    # If SSH key provided as command-line argument, use it (non-interactive mode)
    if [ -n "${1}" ]; then
        CONTROL_HOST_SSH_KEY="${1}"
        printf "%b\n" "${GREEN}Using SSH public key from command-line argument${NC}"
        return
    fi
    
    # Interactive mode: show menu
    printf "\n"
    printf "%b\n" "${BLUE}========================================${NC}"
    printf "%b\n" "${BLUE}SSH Public Key Selection${NC}"
    printf "%b\n" "${BLUE}========================================${NC}"
    printf "\n"
    printf "Please select an option:\n"
    printf "  1) Use default control machine SSH key (recommended)\n"
    printf "  2) Enter/paste a custom SSH public key\n"
    printf "\n"
    printf "Enter your choice [1-2] (default: 1): "
    read choice
    if [ -z "$choice" ]; then
        choice=1
    fi
    
    case $choice in
        1)
            CONTROL_HOST_SSH_KEY="$DEFAULT_SSH_KEY"
            printf "%b\n" "${GREEN}Using default control machine SSH key${NC}"
            ;;
        2)
            printf "\n"
            printf "%b\n" "${YELLOW}Please paste or enter the SSH public key:${NC}"
            printf "%b\n" "${YELLOW}(Press Enter on a new line when finished)${NC}"
            printf "\n"
            read CONTROL_HOST_SSH_KEY
            
            # Validate that a key was entered
            if [ -z "$CONTROL_HOST_SSH_KEY" ]; then
                printf "%b\n" "${RED}Error: No SSH public key provided${NC}"
                exit 1
            fi
            
            # Basic validation - check if it looks like an SSH key (POSIX-compliant)
            case "$CONTROL_HOST_SSH_KEY" in
                ssh-rsa*|ssh-ed25519*|ecdsa-sha2-nistp256*|ecdsa-sha2-nistp384*|ecdsa-sha2-nistp521*)
                    # Valid key format
                    ;;
                *)
                    printf "%b\n" "${YELLOW}Warning: The provided key doesn't appear to be a standard SSH public key format${NC}"
                    printf "Continue anyway? [y/N]: "
                    read confirm
                    case "$confirm" in
                        [Yy]*)
                            # User confirmed, continue
                            ;;
                        *)
                            printf "Aborted.\n"
                            exit 1
                            ;;
                    esac
                    ;;
            esac
            
            printf "%b\n" "${GREEN}Using custom SSH public key${NC}"
            ;;
        *)
            printf "%b\n" "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
}

# Get SSH key (interactive or from argument)
get_ssh_key "${1}"

printf "%b\n" "${GREEN}Starting VM preparation for Ansible management...${NC}"

# Detect OS and set package manager
if [ -f /etc/debian_version ]; then
    PKG_MANAGER="apt"
    UPDATE_CMD="apt update"
    INSTALL_CMD="apt install -y"
    printf "%b\n" "${GREEN}Detected Debian/Ubuntu system${NC}"
elif [ -f /etc/redhat-release ]; then
    PKG_MANAGER="yum"
    UPDATE_CMD="yum check-update || true"
    INSTALL_CMD="yum install -y"
    printf "%b\n" "${GREEN}Detected RHEL/CentOS system${NC}"
elif [ -f /etc/freebsd-update.conf ] || uname -s | grep -q FreeBSD; then
    PKG_MANAGER="pkg"
    UPDATE_CMD="pkg update"
    INSTALL_CMD="pkg install -y"
    printf "%b\n" "${GREEN}Detected FreeBSD system${NC}"
else
    printf "%b\n" "${RED}Error: Unsupported OS. This script supports Debian/Ubuntu, RHEL/CentOS, and FreeBSD${NC}"
    exit 1
fi

# Update package lists
printf "%b\n" "${YELLOW}Updating package lists...${NC}"
if ! eval "$UPDATE_CMD"; then
    if [ "$PKG_MANAGER" = "pkg" ]; then
        printf "%b\n" "${YELLOW}Warning: pkg update failed (this may be normal for EOL FreeBSD versions)${NC}"
        printf "%b\n" "${YELLOW}Continuing with package installation...${NC}"
    else
        printf "%b\n" "${RED}Error: Failed to update package lists${NC}"
        exit 1
    fi
fi

# Install required packages
printf "%b\n" "${YELLOW}Installing required packages (git, sudo, sshpass, python3)...${NC}"
if [ "$PKG_MANAGER" = "apt" ]; then
    $INSTALL_CMD git sudo sshpass python3 python3-pip
elif [ "$PKG_MANAGER" = "yum" ]; then
    # For RHEL, we might need EPEL for some packages
    if ! rpm -q epel-release > /dev/null 2>&1; then
        printf "%b\n" "${YELLOW}Installing EPEL repository...${NC}"
        $INSTALL_CMD epel-release || true
    fi
    $INSTALL_CMD git sudo sshpass python3 python3-pip
elif [ "$PKG_MANAGER" = "pkg" ]; then
    # FreeBSD: sshpass is not available, detect Python version dynamically
    # First, check if python3 is already installed
    if command -v python3 > /dev/null 2>&1; then
        # Python3 is installed, detect version
        PYTHON_VERSION=$(python3 --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2 | tr -d '.')
        printf "%b\n" "${YELLOW}Detected installed Python version: 3.${PYTHON_VERSION#3}${NC}"
    else
        # Python3 not installed, install it first (default version)
        printf "%b\n" "${YELLOW}Installing Python3 (default version)...${NC}"
        $INSTALL_CMD python3
        
        # Now detect the version that was installed
        if command -v python3 > /dev/null 2>&1; then
            PYTHON_VERSION=$(python3 --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2 | tr -d '.')
            printf "%b\n" "${YELLOW}Detected Python version: 3.${PYTHON_VERSION#3}${NC}"
        else
            printf "%b\n" "${RED}Error: Python3 installation failed${NC}"
            exit 1
        fi
    fi
    
    # Validate we have a Python version
    if [ -z "$PYTHON_VERSION" ]; then
        printf "%b\n" "${RED}Error: Could not determine Python version${NC}"
        exit 1
    fi
    
    # Install git, sudo, and pip for the detected Python version
    printf "%b\n" "${YELLOW}Installing git, sudo, and pip for Python ${PYTHON_VERSION}...${NC}"
    $INSTALL_CMD git sudo py${PYTHON_VERSION}-pip
    printf "%b\n" "${YELLOW}Note: sshpass is not available on FreeBSD. SSH key setup will work without it.${NC}"
fi

# Verify Python3 is installed
if ! command -v python3 > /dev/null; then
    printf "%b\n" "${RED}Error: Python3 installation failed${NC}"
    exit 1
fi

# Create ansible user if it doesn't exist
if id "$ANSIBLE_USER" >/dev/null 2>&1; then
    printf "%b\n" "${YELLOW}User '$ANSIBLE_USER' already exists${NC}"
else
    printf "%b\n" "${YELLOW}Creating user '$ANSIBLE_USER'...${NC}"
    # Determine shell - prefer bash if available, otherwise use sh
    USER_SHELL="/bin/sh"
    if command -v bash >/dev/null 2>&1; then
        # Use the actual path where bash is located
        USER_SHELL=$(command -v bash)
    fi
    
    # Use OS-specific user creation command
    if [ "$PKG_MANAGER" = "pkg" ]; then
        # FreeBSD uses pw useradd
        pw useradd -n "$ANSIBLE_USER" -m -s "$USER_SHELL" -c "Ansible user"
    else
        # Linux (Debian/Ubuntu/RHEL) uses useradd
        useradd -m -s "$USER_SHELL" "$ANSIBLE_USER"
    fi
    
    if [ $? -eq 0 ]; then
        printf "%b\n" "${GREEN}User '$ANSIBLE_USER' created successfully${NC}"
    else
        printf "%b\n" "${RED}Error: Failed to create user '$ANSIBLE_USER'${NC}"
        exit 1
    fi
fi

# Create .ssh directory for ansible user
# Get home directory using getent (POSIX-compliant, works on all systems)
ANSIBLE_HOME=$(getent passwd "$ANSIBLE_USER" 2>/dev/null | cut -d: -f6)
if [ -z "$ANSIBLE_HOME" ]; then
    # Fallback: try eval if getent fails (shouldn't happen if user was just created)
    ANSIBLE_HOME=$(eval echo ~$ANSIBLE_USER 2>/dev/null || echo "/home/$ANSIBLE_USER")
fi
SSH_DIR="$ANSIBLE_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

printf "%b\n" "${YELLOW}Setting up SSH directory for '$ANSIBLE_USER'...${NC}"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown "$ANSIBLE_USER:$ANSIBLE_USER" "$SSH_DIR"

# Add control host's SSH public key
printf "%b\n" "${YELLOW}Adding control host's SSH public key...${NC}"
if [ -f "$AUTHORIZED_KEYS" ]; then
    # Check if key already exists
    if grep -Fxq "$CONTROL_HOST_SSH_KEY" "$AUTHORIZED_KEYS" 2>/dev/null; then
        printf "%b\n" "${YELLOW}SSH key already exists in authorized_keys${NC}"
    else
        printf "%b\n" "$CONTROL_HOST_SSH_KEY" >> "$AUTHORIZED_KEYS"
        printf "%b\n" "${GREEN}SSH key added to authorized_keys${NC}"
    fi
else
    printf "%b\n" "$CONTROL_HOST_SSH_KEY" > "$AUTHORIZED_KEYS"
    printf "%b\n" "${GREEN}SSH key added to authorized_keys${NC}"
fi

chmod 600 "$AUTHORIZED_KEYS"
chown "$ANSIBLE_USER:$ANSIBLE_USER" "$AUTHORIZED_KEYS"

# Check if ansible user is already in sudoers
printf "%b\n" "${YELLOW}Configuring sudo access for '$ANSIBLE_USER'...${NC}"
# Set sudoers path based on OS
if [ "$PKG_MANAGER" = "pkg" ]; then
    SUDOERS_FILE="/usr/local/etc/sudoers"
else
    SUDOERS_FILE="/etc/sudoers"
fi

SUDOERS_ENTRY="$ANSIBLE_USER ALL=(ALL:ALL) NOPASSWD:ALL"
if grep -Fxq "$SUDOERS_ENTRY" "$SUDOERS_FILE" 2>/dev/null; then
    printf "%b\n" "${YELLOW}'$ANSIBLE_USER' is already in sudoers${NC}"
else
    # Add to sudoers using visudo for safety
    printf "%b\n" "$SUDOERS_ENTRY" | EDITOR='tee -a' visudo > /dev/null
    printf "%b\n" "${GREEN}'$ANSIBLE_USER' added to sudoers with NOPASSWD${NC}"
fi

# Detect IP address for convenience
detect_ip() {
    # Try multiple methods to get IP address (POSIX-compliant)
    VM_IP=""
    
    # Method 1: hostname -I (Linux, gets first IP)
    if command -v hostname >/dev/null 2>&1; then
        VM_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    # Method 2: Parse ifconfig output (works on both Linux and FreeBSD)
    if [ -z "$VM_IP" ] && command -v ifconfig >/dev/null 2>&1; then
        # Try to get IP from ifconfig (different formats on different systems)
        VM_IP=$(ifconfig 2>/dev/null | grep -E 'inet[[:space:]]' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | sed 's/addr://')
    fi
    
    # Method 3: Try ip command (Linux)
    if [ -z "$VM_IP" ] && command -v ip >/dev/null 2>&1; then
        VM_IP=$(ip addr show 2>/dev/null | grep -E 'inet[[:space:]]' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d'/' -f1)
    fi
    
    # If still no IP, use hostname as fallback
    if [ -z "$VM_IP" ]; then
        VM_IP=$(hostname 2>/dev/null || echo "this_vm_ip_or_hostname")
    fi
    
    printf "%s" "$VM_IP"
}

VM_IP=$(detect_ip)

# Display summary
printf "\n"
printf "%b\n" "${GREEN}========================================${NC}"
printf "%b\n" "${GREEN}VM Preparation Complete!${NC}"
printf "%b\n" "${GREEN}========================================${NC}"
printf "\n"
printf "Summary:\n"
printf "  - User created: %s\n" "$ANSIBLE_USER"
printf "  - SSH key added: Yes\n"
printf "  - Sudo access: NOPASSWD configured\n"
printf "  - Required packages: Installed\n"
printf "\n"
printf "%b\n" "${YELLOW}Next steps:${NC}"
printf "  1. On your control host, run: ./setup_remote.sh %s\n" "$VM_IP"
printf "  2. The control host will deploy localconfig to this VM\n"
printf "\n"
