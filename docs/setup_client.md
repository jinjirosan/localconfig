# setup_client.sh Documentation

## Overview

`setup_client.sh` is a bash script that prepares a fresh VM or server for remote Ansible management. It must be run **on the target VM** (not the control host) before `setup_remote.sh` can deploy localconfig to it.

## Purpose

This script automates the initial setup required for a remote system to be managed by Ansible. It installs prerequisites, creates the ansible user, configures SSH access, and sets up passwordless sudo.

## Prerequisites

- **Operating System**: Debian/Ubuntu or RHEL/CentOS
- **Permissions**: Must be run as root or with sudo privileges
- **Network Access**: Must be able to download packages from repositories
- **Control Host SSH Key**: Either use default key or provide control host's public SSH key

## Usage

### Interactive Mode (Recommended)

```bash
# Copy script to remote VM, then run as root
sudo ./setup_client.sh
```

### Non-Interactive Mode

```bash
# Provide SSH public key as argument
sudo ./setup_client.sh "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
```

## What It Does

### Step 1: Root/Sudo Check

```bash
# Verifies script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    # Exits with error
fi
```

### Step 2: SSH Key Selection

**Option 1: Default Control Machine SSH Key (Recommended)**
- Uses a hardcoded default SSH public key
- Simplest option for standard deployments

**Option 2: Custom SSH Public Key**
- Allows you to paste/enter a custom SSH public key
- Validates key format before proceeding
- Useful when using a different control host

### Step 3: OS Detection

```bash
# Detects OS and sets package manager
if [ -f /etc/debian_version ]; then
    PKG_MANAGER="apt"
elif [ -f /etc/redhat-release ]; then
    PKG_MANAGER="yum"
fi
```

### Step 4: Package Installation

Installs required packages:
- **Debian/Ubuntu**: `git`, `sudo`, `sshpass`, `python3`, `python3-pip`
- **RHEL/CentOS**: Same packages (may install EPEL repository if needed)

### Step 5: Ansible User Creation

```bash
# Creates ansible user if it doesn't exist
useradd -m -s /bin/bash ansible
```

### Step 6: SSH Directory Setup

```bash
# Creates .ssh directory with proper permissions
mkdir -p ~ansible/.ssh
chmod 700 ~ansible/.ssh
chown ansible:ansible ~ansible/.ssh
```

### Step 7: SSH Key Installation

```bash
# Adds control host's SSH public key to authorized_keys
echo "$CONTROL_HOST_SSH_KEY" >> ~ansible/.ssh/authorized_keys
chmod 600 ~ansible/.ssh/authorized_keys
chown ansible:ansible ~ansible/.ssh/authorized_keys
```

### Step 8: Sudo Configuration

```bash
# Adds ansible user to sudoers with NOPASSWD
echo "ansible ALL=(ALL:ALL) NOPASSWD:ALL" | EDITOR='tee -a' visudo
```

## Interactive SSH Key Selection

### Option 1: Default Key (Recommended)

**When to use:**
- Standard deployment scenario
- Using the default control host

**Example:**
```bash
$ sudo ./setup_client.sh

========================================
SSH Public Key Selection
========================================

Please select an option:
  1) Use default control machine SSH key (recommended)
  2) Enter/paste a custom SSH public key

Enter your choice [1-2] (default: 1): 1

Using default control machine SSH key
```

### Option 2: Custom SSH Key

**When to use:**
- Using a different control host
- Need to use a specific SSH key

**Example:**
```bash
$ sudo ./setup_client.sh

========================================
SSH Public Key Selection
========================================

Please select an option:
  1) Use default control machine SSH key (recommended)
  2) Enter/paste a custom SSH public key

Enter your choice [1-2] (default: 1): 2

Please paste or enter the SSH public key:
(Press Enter on a new line when finished)

ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... user@control-host

Using custom SSH public key
```

## Non-Interactive Mode

For automated deployments or scripts:

```bash
# Get SSH public key from control host
SSH_KEY=$(cat ~/.ssh/id_rsa.pub)

# Copy to remote VM and run
echo "$SSH_KEY" | ssh root@remote-vm "cat > /tmp/setup_client.sh && chmod +x /tmp/setup_client.sh && /tmp/setup_client.sh \"$SSH_KEY\""
```

## Example Output

### Successful Execution

```
Starting VM preparation for Ansible management...
Detected Debian/Ubuntu system
Updating package lists...
Installing required packages (git, sudo, sshpass, python3)...
Setting up SSH directory for 'ansible'...
Adding control host's SSH public key...
SSH key added to authorized_keys
Configuring sudo access for 'ansible'...
'ansible' added to sudoers with NOPASSWD

========================================
VM Preparation Complete!
========================================

Summary:
  - User created: ansible
  - SSH key added: Yes
  - Sudo access: NOPASSWD configured
  - Required packages: Installed

Next steps:
  1. On your control host, run: ./setup_remote.sh <this_vm_ip_or_hostname>
  2. The control host will deploy localconfig to this VM
```

## Configuration Applied

After successful execution, the remote VM has:

### User Created
- **Username**: `ansible` (default)
- **Home Directory**: `/home/ansible`
- **Shell**: `/bin/bash`

### Packages Installed
- `git`, `sudo`, `sshpass`, `python3`, `python3-pip`

### SSH Configuration
- `.ssh/` directory created with proper permissions
- Control host's SSH public key in `authorized_keys`
- Proper file permissions (600 for authorized_keys, 700 for .ssh)

### Sudo Configuration
- `ansible` user added to `/etc/sudoers`
- NOPASSWD access configured (required for Ansible automation)

## Error Handling

The script handles various error conditions:

1. **Not running as root**: Exits with clear error message
2. **Unsupported OS**: Exits with error message
3. **Package installation failure**: Exits with error
4. **Python3 installation failure**: Exits with error
5. **Invalid SSH key format**: Warns and asks for confirmation

## Troubleshooting

### Issue: "This script must be run as root or with sudo"

**Solution:**
```bash
# Run with sudo
sudo ./setup_client.sh

# Or switch to root
su -
./setup_client.sh
```

### Issue: "Unsupported OS"

**Solution:** The script supports Debian/Ubuntu and RHEL/CentOS. For other distributions, you may need to:
1. Install packages manually
2. Create ansible user manually
3. Configure SSH and sudo manually

### Issue: "Python3 installation failed"

**Solution:**
```bash
# Check package repositories
apt update  # or yum check-update

# Try manual installation
apt install python3 python3-pip  # Debian/Ubuntu
yum install python3 python3-pip   # RHEL/CentOS
```

### Issue: SSH key already exists

**Solution:** The script checks for existing keys and won't duplicate them. This is safe to ignore.

### Issue: "Warning: The provided key doesn't appear to be a standard SSH public key format"

**Solution:** 
- Verify you're pasting the complete public key (starts with `ssh-rsa`, `ssh-ed25519`, etc.)
- Ensure there are no extra spaces or line breaks
- If you're certain the key is correct, answer 'y' to continue

## Security Considerations

1. **Root Access Required**: Script must run as root to create users and configure sudo
2. **SSH Key Security**: Ensure you're using the correct control host's public key
3. **Sudo NOPASSWD**: Required for Ansible automation, but grants passwordless sudo to ansible user
4. **Network Security**: Ensure SSH connections are over secure networks

## Integration with Other Scripts

### Prerequisite for: setup_remote.sh

**Must be run first** on the remote VM before `setup_remote.sh` can deploy:

```bash
# Step 1: On remote VM
sudo ./setup_client.sh

# Step 2: On control host
./setup_remote.sh <remote_vm_ip>
```

### Relationship: setup_remote.sh

- `setup_client.sh` prepares the remote VM
- `setup_remote.sh` deploys localconfig to the prepared VM
- Both scripts work together for remote deployment

## Best Practices

1. **Run as root**: Always run with `sudo` or as root user
2. **Verify SSH key**: Double-check you're using the correct control host's SSH public key
3. **Test connectivity**: After running, test SSH from control host:
   ```bash
   ssh ansible@<remote_vm_ip>
   ```
4. **Check sudo**: Verify sudo access works:
   ```bash
   ssh ansible@<remote_vm_ip> "sudo -n true"
   ```
5. **Keep script updated**: Use the latest version of the script

## Advanced Usage

### Custom Ansible User

To use a different username (not `ansible`), you'll need to modify the script:

```bash
# Edit the script
ANSIBLE_USER="myuser"  # Change this line
```

### Multiple Control Hosts

If you need to allow SSH access from multiple control hosts:

```bash
# Run script multiple times with different keys
sudo ./setup_client.sh "ssh-rsa ... control-host-1"
# Manually add second key
echo "ssh-rsa ... control-host-2" >> ~ansible/.ssh/authorized_keys
```

### Automated Deployment

For automated deployments, use non-interactive mode:

```bash
# From control host
SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
scp setup_client.sh root@remote-vm:/tmp/
ssh root@remote-vm "/tmp/setup_client.sh \"$SSH_KEY\""
```

## See Also

- [setup_remote.md](setup_remote.md) - Remote deployment (run after this script)
- [architecture.md](architecture.md) - Overall system architecture
- [playbooks.md](playbooks.md) - Playbook and roles documentation

