# setup_local.sh Documentation

## Overview

`setup_local.sh` is a bash script that automates the deployment of localconfig to the local machine. It handles Ansible installation, user selection, and executes the Ansible playbook to configure the local development environment.

## Purpose

This script is designed for setting up your development environment on the machine where you cloned the localconfig repository. It's the simplest way to get started with localconfig.

## Prerequisites

- **Operating System**: Debian/Ubuntu or RHEL/CentOS
- **Permissions**: User must have sudo access (will be prompted if needed)
- **Repository**: Script must be run from the localconfig repository root directory

## Usage

### Basic Usage

```bash
cd /path/to/localconfig
./setup_local.sh
```

### What It Does

1. **Checks/Installs Ansible**: Automatically installs Ansible if not present
2. **Validates Environment**: Ensures script is run from repository root
3. **Interactive User Selection**: Prompts for which users to configure
4. **Creates/Updates hosts.ini**: Generates or updates Ansible inventory file
5. **Executes Playbook**: Runs the Ansible playbook to deploy localconfig

## User Selection Options

The script provides three interactive options:

### Option 1: Current User and Root (Default)

**What it does:**
- Configures the current logged-in user and root
- Adds current user to sudoers (if not already present)
- Deploys dotfiles to current user and root

**Example:**
```bash
$ ./setup_local.sh
# Select option 1 (or press Enter for default)
# Result: Configures user 'john' and root
```

### Option 2: Specific User(s)

**What it does:**
- Allows you to specify one or more users (space-separated)
- Adds all specified users to sudoers
- Deploys dotfiles to all specified users

**Single User Example:**
```bash
$ ./setup_local.sh
# Select option 2
# Enter: john
# Result: Configures user 'john' and root
```

**Multiple Users Example:**
```bash
$ ./setup_local.sh
# Select option 2
# Enter: john jane bob
# Result: Configures users 'john', 'jane', 'bob', and root
# All three users are added to sudoers
# All three users get dotfiles
```

### Option 3: All Users

**What it does:**
- Configures all users with home directories in `/home/`
- Does NOT add "all" to sudoers (only ansible_user)
- Deploys dotfiles to all users in `/home/`

**Example:**
```bash
$ ./setup_local.sh
# Select option 3
# Result: Configures all users in /home/ and root
```

## Detailed Workflow

### Step 1: Environment Validation

```bash
# Checks if running from repository root
if [ ! -f "playbooks/site.yml" ] || [ ! -d "roles" ]; then
    # Exits with error
fi
```

### Step 2: Ansible Installation

```bash
# Detects OS and installs Ansible
if [ -f /etc/debian_version ]; then
    sudo apt update && sudo apt install ansible -y
elif [ -f /etc/redhat-release ]; then
    sudo yum install epel-release -y && sudo yum install ansible -y
fi
```

### Step 3: User Selection

Interactive menu prompts for user selection:
- Option 1: Current user (default)
- Option 2: Specific user(s) - space-separated
- Option 3: All users

### Step 3a: Additional Sudo Users

Prompts for additional users to add to passwordless sudo (optional):
- Enter space-separated usernames or press Enter to skip
- These users get sudo access but not localconfig dotfiles (unless "all users" was selected)

### Step 3b: Firewall Configuration (Optional)

Prompts for firewall (security_setup role) configuration:
1. **Enable firewall?** [y/N] - Choose whether to enable the firewall
2. **SSH allowed source ranges** - If firewall enabled:
   - Option 1: Use defaults (`172.16.233.0/26 172.16.234.0/26`)
   - Option 2: Enter custom CIDR ranges (space-separated)
3. **DNS servers** - If firewall enabled:
   - Option 1: Use defaults (`172.16.234.16 172.16.234.26`)
   - Option 2: Enter custom DNS server IPs (space-separated)

### Step 4: hosts.ini Management

Creates or updates `hosts.ini` with local configuration:

```ini
[local]
localhost ansible_connection=local ansible_user=<current_user> ansible_become=yes ansible_python_interpreter=/usr/bin/python3
```

### Step 5: Sudo Password Check

```bash
# Checks if passwordless sudo is available
if ! sudo -n true 2>/dev/null; then
    # Will prompt for sudo password
    NEED_BECOME_PASS="--ask-become-pass"
fi
```

### Step 6: Playbook Execution

Executes the Ansible playbook with appropriate parameters:

```bash
ansible-playbook playbooks/site.yml \
    -i hosts.ini \
    -l local \
    --extra-vars "target_user=$TARGET_USER replace_motd=$REPLACE_MOTD additional_sudo_users='$ADDITIONAL_SUDO_USERS' security_setup_enabled=$SECURITY_SETUP_ENABLED security_ssh_allowed_networks='$SECURITY_SSH_ALLOWED' security_dns_servers='$SECURITY_DNS_SERVERS'" \
    $NEED_BECOME_PASS
```

## Configuration Applied

When the script completes successfully, the following is configured:

### Tools Installed (System-wide)
- `sudo`, `vim`, `htop`, `screen`, `net-tools`
- `git`, `cifs-utils`, `gnupg`, `curl`, `gcc`, `mlocate`

### Users Configured
- **Sudoers**: `ansible_user` + `target_user(s)` + `additional_sudo_users` (if not "all")
- **Dotfiles**: `.vimrc`, `.bashrc`, `.screenrc`, `.curlrc`
- **Vim Configuration**: Badwolf theme, airline plugin, autoload scripts

### Login Configuration
- **MOTD**: System information and ASCII art
- **SSH Banner**: Login warning banner

### Firewall Configuration (if enabled)
- **Linux (Debian/Ubuntu, RHEL)**: nftables firewall with default-deny policies
- **FreeBSD**: PF firewall with default-deny policies
- **SSH Access**: Restricted to configured source subnets
- **Outbound**: Allows DNS, DHCP, HTTP/HTTPS, SSH; logs all other attempts
- **Log Limits**: 500MB total size, 14-day retention

### Files Created
- `hosts.ini`: Ansible inventory file (if not exists)
- `discovered_ssh_keys/`: Directory with SSH key backups (if applicable)

## Example Output

### Successful Execution

```
Preparing to deploy localconfig to local machine...

========================================
Target User Selection
========================================

Please select which user(s) to configure with localconfig:
  1) Current user (john) and root only (default)
  2) Specific user(s) - space-separated for multiple
  3) All users on the system

Enter your choice [1-3] (default: 1): 2

Enter username(s) to configure (space-separated for multiple):
Username(s): jane bob
Selected: Configure 2 users: jane bob

Current user (john) has passwordless sudo access.

========================================
Deploying localconfig to local machine
========================================

PLAY [Initial Setup] *********************************************************
TASK [Check if target_user(s) are in sudoers] ********************************
ok: [localhost] => (item=jane)
ok: [localhost] => (item=bob)

TASK [Add target_user(s) to sudoers] *****************************************
changed: [localhost] => (item=jane)
changed: [localhost] => (item=bob)

PLAY [Setup All Systems] ******************************************************
...

========================================
Local setup completed successfully!
========================================

Localconfig has been deployed to: localhost
Ansible user: john
Target user configured: jane bob (and root)
```

## Error Handling

The script handles various error conditions:

1. **Not in repository root**: Exits with error message
2. **Unsupported OS**: Prompts for manual Ansible installation
3. **Empty username**: Validates input and exits if empty
4. **Playbook failure**: Displays error message and exits with code 1

## Troubleshooting

### Issue: "This script must be run from the localconfig repository root"

**Solution**: Ensure you're in the directory containing `playbooks/` and `roles/`:

```bash
cd /path/to/localconfig
./setup_local.sh
```

### Issue: "Unsupported OS. Please install Ansible manually"

**Solution**: Install Ansible manually for your OS, then re-run the script.

### Issue: Sudo password prompt appears

**Solution**: This is normal if your user doesn't have passwordless sudo. Enter your password when prompted.

### Issue: Playbook fails with permission errors

**Solution**: Ensure your user has sudo access:

```bash
sudo -v  # Test sudo access
```

## Integration with Other Scripts

- **Independent**: Can be run standalone without other scripts
- **Compatible**: Uses same playbook and roles as `setup_remote.sh`
- **Consistent**: Produces same end result as remote deployment

## Best Practices

1. **Run from repository root**: Always run from the cloned repository directory
2. **Review user selection**: Choose appropriate option based on your needs
3. **Check sudo access**: Ensure you have sudo privileges before running
4. **Backup existing configs**: Script is idempotent, but consider backing up existing dotfiles

## See Also

- [setup_remote.md](setup_remote.md) - Remote deployment documentation
- [setup_client.md](setup_client.md) - Client preparation documentation
- [architecture.md](architecture.md) - Overall system architecture
- [playbooks.md](playbooks.md) - Playbook and roles documentation

