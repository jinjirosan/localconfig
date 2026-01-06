# setup_remote.sh Documentation

## Overview

`setup_remote.sh` is a bash script that deploys localconfig to remote VMs using Ansible over SSH. It runs on the **control host** (where the localconfig repository is cloned) and connects to remote systems that have been prepared with `setup_client.sh`.

## Purpose

This script automates the deployment of localconfig to remote virtual machines or servers. It handles SSH connectivity, inventory management, and executes the Ansible playbook remotely.

## Prerequisites

### On Control Host
- **Operating System**: Debian/Ubuntu or RHEL/CentOS
- **Ansible**: Installed (script will check and error if missing)
- **SSH Key**: SSH key pair should exist (script will generate if missing)
- **Repository**: Script must be run from localconfig repository root
- **Network Access**: Must be able to SSH to remote host

### On Remote Host
- **Prepared with setup_client.sh**: Remote host must have been prepared using `setup_client.sh`
- **SSH Access**: Control host's SSH public key must be in remote host's `authorized_keys`
- **Ansible User**: `ansible` user (or specified user) must exist with NOPASSWD sudo

## Usage

### Basic Usage

```bash
cd /path/to/localconfig
./setup_remote.sh <remote_host_ip_or_hostname>
```

### With Custom Ansible User

```bash
./setup_remote.sh <remote_host_ip_or_hostname> <ansible_user>
```

### Examples

**Deploy to remote host with default ansible user:**
```bash
./setup_remote.sh 172.16.234.54
```

**Deploy to remote host with custom ansible user:**
```bash
./setup_remote.sh 172.16.234.54 myuser
```

**Deploy to remote host by hostname:**
```bash
./setup_remote.sh server.example.com
```

## Workflow

### Step 1: Parameter Validation

```bash
# Checks if remote host is provided
if [ -z "$REMOTE_HOST" ]; then
    # Displays usage and exits
fi
```

### Step 2: Interactive User Selection

Prompts for which users to configure:
- **Option 1**: Ansible user and root only (default)
- **Option 2**: Specific user(s) - space-separated for multiple
- **Option 3**: All users on the system

### Step 3: Environment Validation

```bash
# Checks if in repository root
# Checks if Ansible is installed
# Checks if SSH key exists (generates if missing)
```

### Step 4: SSH Connectivity Test

```bash
# Tests SSH connection to remote host
ssh -o ConnectTimeout=5 "$ANSIBLE_USER@$REMOTE_HOST" "echo 'Connection successful'"
```

### Step 5: Inventory Management

Creates or updates `hosts.ini` with remote host entry:

```ini
[remote]
172.16.234.54 ansible_user=ansible ansible_python_interpreter=/usr/bin/python3
```

### Step 6: Ansible Connectivity Test

```bash
# Tests Ansible connectivity
ansible "$REMOTE_HOST" -i "$HOSTS_INI" -m ping -u "$ANSIBLE_USER"
```

### Step 7: Playbook Execution

Executes the Ansible playbook remotely:

```bash
ansible-playbook playbooks/site.yml \
    -i "$HOSTS_INI" \
    -l "$REMOTE_HOST" \
    -u "$ANSIBLE_USER" \
    --extra-vars "target_user=$TARGET_USER"
```

## User Selection Options

### Option 1: Ansible User and Root (Default)

**What it does:**
- Configures the ansible user (usually `ansible`) and root
- Adds ansible user to sudoers (if not already present)
- Deploys dotfiles to ansible user and root

**Example:**
```bash
$ ./setup_remote.sh 172.16.234.54
# Select option 1 (or press Enter for default)
# Result: Configures 'ansible' user and root
```

### Option 2: Specific User(s)

**What it does:**
- Allows you to specify one or more users (space-separated)
- Adds all specified users to sudoers
- Deploys dotfiles to all specified users

**Single User Example:**
```bash
$ ./setup_remote.sh 172.16.234.54
# Select option 2
# Enter: john
# Result: Configures user 'john' and root
```

**Multiple Users Example:**
```bash
$ ./setup_remote.sh 172.16.234.54
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
$ ./setup_remote.sh 172.16.234.54
# Select option 3
# Result: Configures all users in /home/ and root
```

## Configuration Applied

When the script completes successfully, the following is configured on the remote host:

### Tools Installed (System-wide)
- `sudo`, `vim`, `htop`, `screen`, `net-tools`
- `git`, `cifs-utils`, `gnupg`, `curl`, `gcc`, `mlocate`

### Users Configured
- **Sudoers**: `ansible_user` + `target_user(s)` (if not "all")
- **Dotfiles**: `.vimrc`, `.bashrc`, `.screenrc`, `.curlrc`
- **Vim Configuration**: Badwolf theme, airline plugin, autoload scripts

### Files Created
- `hosts.ini`: Updated with remote host entry
- `discovered_ssh_keys/`: Directory with SSH key backups from remote host

## Example Output

### Successful Execution

```
========================================
Target User Selection
========================================

Please select which user(s) to configure with localconfig:
  1) Ansible user and root only (default)
  2) Specific user(s) - space-separated for multiple
  3) All users on the system

Enter your choice [1-3] (default: 1): 2

Enter username(s) to configure (space-separated for multiple):
Username(s): john jane
Selected: Configure 2 users: john jane

Preparing to deploy localconfig to remote host: 172.16.234.54
Using SSH public key from: /home/user/.ssh/id_rsa.pub
Testing SSH connectivity to 172.16.234.54...
SSH connection successful
Adding 172.16.234.54 to hosts.ini...
Remote host added to hosts.ini
Testing Ansible connectivity...
Ansible connectivity test successful

========================================
Deploying localconfig to 172.16.234.54
========================================

PLAY [Initial Setup] *********************************************************
TASK [Check if target_user(s) are in sudoers] ********************************
ok: [172.16.234.54] => (item=john)
ok: [172.16.234.54] => (item=jane)

TASK [Add target_user(s) to sudoers] *****************************************
changed: [172.16.234.54] => (item=john)
changed: [172.16.234.54] => (item=jane)

PLAY [Setup All Systems] ******************************************************
...

========================================
Deployment completed successfully!
========================================

Localconfig has been deployed to: 172.16.234.54
Ansible user: ansible
Target user configured: john jane (and root)
```

## Error Handling

The script handles various error conditions:

1. **Missing remote host**: Displays usage and exits
2. **Not in repository root**: Exits with error message
3. **Ansible not installed**: Displays installation instructions
4. **SSH connection failure**: Provides troubleshooting steps
5. **Ansible connectivity failure**: Lists common issues
6. **Playbook failure**: Displays error message and exits

## Troubleshooting

### Issue: "Cannot connect to <host> as <user>"

**Possible causes:**
- Remote host not prepared with `setup_client.sh`
- SSH key not added to remote host
- Network connectivity issues
- Firewall blocking SSH

**Solution:**
```bash
# Test SSH manually
ssh ansible@172.16.234.54

# If connection fails, ensure setup_client.sh was run on remote host
```

### Issue: "Ansible connectivity test failed"

**Possible causes:**
- SSH key authentication not working
- Ansible user doesn't have sudo access
- Python3 not installed on remote host

**Solution:**
```bash
# Test SSH key authentication
ssh -i ~/.ssh/id_rsa ansible@172.16.234.54

# Verify sudo access on remote host
ssh ansible@172.16.234.54 "sudo -n true"

# Check Python3 on remote host
ssh ansible@172.16.234.54 "python3 --version"
```

### Issue: "SSH public key not found"

**Solution:** The script will automatically generate an SSH key pair if missing. Alternatively:

```bash
# Generate SSH key manually
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
```

### Issue: Remote host already exists in hosts.ini

**Solution:** The script automatically updates the existing entry. No action needed.

## Integration with Other Scripts

### Prerequisites: setup_client.sh

**Must be run first** on the remote host before using `setup_remote.sh`:

```bash
# On remote host
./setup_client.sh
```

### Relationship: setup_local.sh

- Uses the same playbook and roles
- Produces the same end result
- Only difference is execution location (local vs remote)

## Best Practices

1. **Prepare remote host first**: Always run `setup_client.sh` on remote host before deployment
2. **Test SSH connectivity**: Verify SSH access before running script
3. **Use consistent ansible_user**: Use the same ansible user across deployments
4. **Review inventory**: Check `hosts.ini` after deployment to verify configuration
5. **Monitor output**: Watch for errors during playbook execution

## Security Considerations

1. **SSH Key Security**: Ensure SSH private keys are properly secured
2. **Sudo Access**: Ansible user requires NOPASSWD sudo (configured by setup_client.sh)
3. **Network Security**: SSH connections should be over secure networks
4. **Key Backup**: Script backs up existing SSH keys before modification

## Advanced Usage

### Deploying to Multiple Hosts

The script can be run multiple times for different hosts:

```bash
./setup_remote.sh 172.16.234.54
./setup_remote.sh 172.16.234.55
./setup_remote.sh 172.16.234.56
```

Each host is added to `hosts.ini` in the `[remote]` section.

### Using Custom Ansible User

If you've configured a different user on the remote host:

```bash
./setup_remote.sh 172.16.234.54 myuser
```

## See Also

- [setup_client.md](setup_client.md) - Remote host preparation (must run first)
- [setup_local.md](setup_local.md) - Local deployment documentation
- [architecture.md](architecture.md) - Overall system architecture
- [playbooks.md](playbooks.md) - Playbook and roles documentation

