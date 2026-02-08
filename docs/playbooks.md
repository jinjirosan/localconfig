# Playbooks and Roles Documentation

## Overview

The Ansible playbook (`playbooks/site.yml`) orchestrates the deployment of localconfig through several specialized roles, including optional firewall (security_setup) configuration. This document describes the playbook structure, each role's responsibilities, and how they work together.

## Main Playbook: `site.yml`

### Structure

The playbook consists of two plays:

1. **Initial Setup Play**: Configures sudoers for target users
2. **Setup All Systems Play**: Executes all roles to configure the system

### Play 1: Initial Setup

**Purpose**: Configure sudo access for target users before running roles.

**Key Features**:
- Converts space-separated `target_user` string to a list for multiple users
- Checks if target users are already in sudoers
- Adds target users to sudoers with NOPASSWD access
- Skips sudoers configuration when `target_user="all"`

**Variables**:
- `target_user`: User(s) to configure (can be space-separated string or "all")
- `target_users_list`: Converted list of users (automatically generated)

**Tasks**:
1. Check if target_user(s) are in sudoers
2. Add target_user(s) to sudoers (if not already present)

**Example**:
```yaml
# Single user
target_user: "john"
# Result: Adds john to sudoers

# Multiple users
target_user: "john jane bob"
# Result: Adds john, jane, and bob to sudoers

# All users
target_user: "all"
# Result: Skips sudoers configuration (only ansible_user gets sudo)
```

### Play 2: Setup All Systems

**Purpose**: Execute all roles to configure SSH, tools, and Vim.

**Key Features**:
- Gathers system facts (OS detection, etc.)
- Executes three roles in sequence
- Sets `files_dir` variable for role access to configuration files

**Roles Executed**:
1. `ssh_setup`
2. `tools_setup`
3. `vim_config`
4. `login_setup`
5. `security_setup` (only when `security_setup_enabled` is true, e.g. when you answer "yes" to "Enable firewall?" in setup_remote.sh or setup_local.sh)

**Variables**:
- `files_dir`: Path to `files/` directory containing dotfiles and Vim configs
- `target_user`: Passed through from first play or defaults to `ansible_user`
- `security_setup_enabled`: Set by setup_remote.sh / setup_local.sh when you enable the firewall
- `security_ssh_allowed_networks`: Space-separated CIDR ranges for SSH (e.g. `172.16.233.0/26 172.16.234.0/26`)
- `security_dns_servers`: Space-separated DNS server IPs for outbound allow list

## Role: ssh_setup

### Purpose

Configures SSH key-based authentication between control host and target systems.

### Tasks

#### 1. OS Detection
- Detects if system is Debian/Ubuntu
- Used to determine if `sshpass` should be installed

#### 2. SSH Key Generation
- Ensures SSH key pair exists on control machine
- Generates 2048-bit RSA key if missing
- Runs on localhost (control machine)

#### 3. sshpass Installation
- Installs `sshpass` on Debian/Ubuntu systems
- Required for password-based SSH setup
- Runs on localhost (control machine)

#### 4. SSH Key Deployment
- Fetches public key from control machine
- Adds public key to target system's `authorized_keys`
- Configures for `ansible_user`

#### 5. SSH Key Backup
- Retrieves existing SSH keys from target system
- Backs up keys to `discovered_ssh_keys/` directory
- Creates backup file: `discovered_ssh_keys/<hostname>_keys.txt`

### Configuration Applied

- **Control Machine**: SSH key pair (if generated)
- **Target System**: Control host's public key in `authorized_keys`
- **Backup**: Existing SSH keys saved to `discovered_ssh_keys/`

### Example Output

```
TASK [ssh_setup : Ensure SSH key is present on control machine] ****
ok: [localhost]

TASK [ssh_setup : Add the SSH key to the remote hosts] ************
changed: [172.16.234.54]

TASK [ssh_setup : Store the list of keys for each host] ***********
changed: [localhost]
```

## Role: tools_setup

### Purpose

Installs essential development tools and configures sudo access for the ansible user.

### Tasks

#### 1. OS Detection
- Detects Debian/Ubuntu vs RHEL
- Sets `pkg_manager` fact (apt or yum)

#### 2. Sudo Installation
- Installs `sudo` package on Debian/Ubuntu (if missing)
- RHEL systems typically have sudo pre-installed

#### 3. Ansible User Sudo Configuration
- Checks if `ansible_user` is in sudoers
- Adds `ansible_user` to sudoers with NOPASSWD access
- Uses `visudo` for safe sudoers modification

#### 4. Package Installation
- **Debian/Ubuntu**: Installs packages from `debian_ubuntu_packages` list
- **RHEL**: Installs packages from `rhel_packages` list
- Packages installed system-wide (available to all users)

#### 5. Package Verification
- Verifies all packages were installed successfully
- Uses `dpkg -l` for Debian/Ubuntu
- Uses `dnf list installed` for RHEL

### Packages Installed

**Debian/Ubuntu** (from `group_vars/all.yml`):
- `sudo`, `vim`, `htop`, `screen`, `net-tools`
- `git`, `cifs-utils`, `gnupg`, `curl`, `gcc`, `mlocate`

**RHEL** (from `group_vars/all.yml`):
- Similar packages (RHEL-specific package names)

### Configuration Applied

- **System-wide**: All packages installed for all users
- **Sudoers**: `ansible_user` added with NOPASSWD access
- **Package Manager**: Automatically selected based on OS

### Example Output

```
TASK [tools_setup : Detect if system is Debian/Ubuntu] ***********
ok: [172.16.234.54]

TASK [tools_setup : Add ansible_user to sudoers with NOPASSWD] ***
changed: [172.16.234.54]

TASK [tools_setup : Install essential tools for Debian/Ubuntu] ***
changed: [172.16.234.54] => (item=sudo)
changed: [172.16.234.54] => (item=vim)
...
```

## Role: login_setup

Configures login banners, MOTD, and SSH banner. See role tasks and templates for details.

## Role: security_setup (optional)

### Purpose

Deploys the appropriate stateful firewall per OS with default-deny inbound and outbound filtering, allows SSH only from configurable subnets, allows DNS/DHCP and selected outbound (HTTP/HTTPS, SSH), and logs outbound drops. Only runs when **Enable firewall (security_setup role)?** is answered with **yes** in `setup_remote.sh` or `setup_local.sh`.

### When It Runs

- **setup_remote.sh**: After MOTD preview, you are asked: (1) Enable firewall? (2) SSH allowed source ranges (option 1 = defaults, option 2 = custom CIDRs), (3) DNS servers (option 1 = defaults, option 2 = custom IPs).
- **setup_local.sh**: After additional sudo users, the same three prompts are shown.
- The role is executed only when `security_setup_enabled` is true (i.e. you chose to enable the firewall).

### OS-Specific Behavior

- **Debian / Ubuntu**: nftables; rules in `/etc/nftables.conf`; outbound drops logged with prefix `nftables-drop-out` (visible in `journalctl -k` and in the login "Top Blocked Destinations" block in `.bashrc`).
- **RHEL / CentOS**: nftables; firewalld is disabled and masked; same rules and logging as Debian.
- **FreeBSD**: PF; rules in `/etc/pf.conf`; outbound blocks logged to syslog (parsed in `.bashrc` for "Top Blocked Destinations").

### Log Limits (Linux)

- journald is configured via a drop-in under `/etc/systemd/journald.conf.d/` with `SystemMaxUse=500M` and `MaxAge=14d` (2 weeks).

### Variables (from prompts or defaults)

- **`security_ssh_allowed_networks`**: CIDR list for SSH (default: `172.16.233.0/26 172.16.234.0/26`). Passed as space-separated string from setup scripts; role splits into a list.
- **`security_dns_servers`**: DNS server IPs for outbound allow (default: `172.16.234.16 172.16.234.26`). Passed as space-separated string; role splits into a list.

### Verifying Firewall Status

**Linux (nftables):**
```bash
# Check service status
systemctl status nftables

# View active rules
nft list ruleset

# View rules with counters
nft list ruleset -a

# Check firewall logs (outbound drops)
journalctl -k --since today | grep "nftables-drop-out"
```

**FreeBSD (PF):**
```bash
# Check PF status
pfctl -s info

# View active rules
pfctl -s rules

# Check firewall logs (outbound blocks)
grep "pf-drop-out" /var/log/messages
```

**Login Display:**
The deployed `.bashrc` automatically shows "Top Blocked Destinations (today)" at login, parsing firewall logs to display the most frequently blocked outbound connection attempts.

## Role: vim_config

### Purpose

Deploys Vim configuration, dotfiles, and user environment files to specified users.

### Tasks

#### 1. Vim Version Detection
- Detects installed Vim version dynamically
- Extracts version number (e.g., "8.2" → "82")
- Used to deploy to correct system directories

#### 2. Ansible User Configuration
- Always configures `ansible_user` with dotfiles
- Copies `.vimrc`, `.bashrc`, `.screenrc`, `.curlrc`
- Creates `.vim` directory

#### 3. Target User Configuration
- Handles three scenarios:
  - **Single user**: Configures one specific user
  - **Multiple users**: Configures space-separated list of users
  - **All users**: Configures all users in `/home/`

#### 4. Root User Configuration
- Always configures root user with dotfiles
- Ensures root has same environment as other users

#### 5. System-wide Vim Configuration
- Deploys Badwolf color scheme to `/usr/share/vim/vim<version>/colors/`
- Deploys vim-airline plugin to `/usr/share/vim/vim<version>/plugin/`
- Deploys all autoload scripts to `/usr/share/vim/vim<version>/autoload/`

### User Configuration Logic

#### Single User
```yaml
target_user: "john"
# Result: Configures john and root
```

#### Multiple Users
```yaml
target_user: "john jane bob"
# Result: Configures john, jane, bob, and root
# All users get dotfiles and are added to sudoers
```

#### All Users
```yaml
target_user: "all"
# Result: Configures all users in /home/ and root
# Does NOT add "all" to sudoers (only ansible_user)
```

### Files Deployed

**Per User**:
- `~/.vimrc` - Vim configuration
- `~/.bashrc` - Bash configuration
- `~/.screenrc` - Screen configuration
- `~/.curlrc` - Curl configuration
- `~/.vim/` - Vim directory (created)

**System-wide**:
- `/usr/share/vim/vim<version>/colors/badwolf.vim`
- `/usr/share/vim/vim<version>/plugin/airline.vim`
- `/usr/share/vim/vim<version>/plugin/airline-themes.vim`
- `/usr/share/vim/vim<version>/autoload/*` - All autoload scripts

### Example Output

```
TASK [vim_config : Detect Vim version] ****************************
ok: [172.16.234.54]

TASK [vim_config : Copy configuration files to ansible user] *****
changed: [172.16.234.54] => (item=.vimrc)
changed: [172.16.234.54] => (item=.bashrc)
...

TASK [vim_config : Copy configuration files to target users] *****
changed: [172.16.234.54] => (item=john: .vimrc)
changed: [172.16.234.54] => (item=john: .bashrc)
...

TASK [vim_config : Copy badwolf.vim color theme] ******************
changed: [172.16.234.54]
```

## Variables

### Playbook Variables

**`target_user`**:
- **Type**: String
- **Default**: `ansible_user` or current user
- **Values**: 
  - Single username: `"john"`
  - Multiple users: `"john jane bob"`
  - All users: `"all"`
- **Usage**: Determines which users get dotfiles and sudoers access

**`target_users_list`**:
- **Type**: List
- **Auto-generated**: Converted from `target_user` string
- **Usage**: Used for looping through multiple users

**`files_dir`**:
- **Type**: String (path)
- **Default**: `{{ playbook_dir }}/../files`
- **Usage**: Points to directory containing dotfiles and Vim configs

### Role Variables

**`ansible_user`**:
- **Type**: String
- **Source**: Ansible inventory (`hosts.ini`)
- **Usage**: User to connect as and configure

**`debian_ubuntu_packages`**:
- **Type**: List
- **Source**: `group_vars/all.yml`
- **Usage**: Packages to install on Debian/Ubuntu

**`rhel_packages`**:
- **Type**: List
- **Source**: `group_vars/all.yml`
- **Usage**: Packages to install on RHEL

**`security_setup_enabled`**:
- **Type**: Boolean (string "true"/"false" from scripts)
- **Source**: `--extra-vars` from setup_remote.sh or setup_local.sh
- **Usage**: When true, the security_setup role runs and configures the firewall

**`security_ssh_allowed_networks`**:
- **Type**: String (space-separated CIDRs) or list
- **Source**: Setup script prompts or role defaults
- **Usage**: Subnets allowed to connect to SSH (e.g. `172.16.233.0/26 172.16.234.0/26`)

**`security_dns_servers`**:
- **Type**: String (space-separated IPs) or list
- **Source**: Setup script prompts or role defaults
- **Usage**: DNS servers allowed for outbound (e.g. `172.16.234.16 172.16.234.26`)

**Login display (.bashrc)**: The deployed `.bashrc` shows at login (after listening ports): **Active Outbound Connections** (Linux: `ss`, FreeBSD: `netstat`, excluding SSH port 22) and **Top Blocked Destinations (today)** (from firewall logs: journalctl on Linux, syslog on FreeBSD).

## Execution Flow

```
playbooks/site.yml
    │
    ├─► Play 1: Initial Setup
    │   ├─► Convert target_user to list
    │   ├─► Check sudoers for each user
    │   └─► Add users to sudoers
    │
    └─► Play 2: Setup All Systems
        ├─► Gather facts (OS detection)
        │
        ├─► Role: ssh_setup
        │   ├─► Generate SSH keys
        │   ├─► Deploy SSH keys
        │   └─► Backup SSH keys
        │
        ├─► Role: tools_setup
        │   ├─► Detect OS
        │   ├─► Install sudo
        │   ├─► Configure ansible_user sudo
        │   └─► Install packages
        │
        ├─► Role: login_setup
        │   └─► MOTD, SSH banner, etc.
        │
        ├─► Role: security_setup (if security_setup_enabled)
        │   ├─► Linux: nftables + journald limits
        │   └─► FreeBSD: PF
        │
        └─► Role: vim_config
            ├─► Detect Vim version
            ├─► Configure ansible_user
            ├─► Configure target_user(s)
            ├─► Configure root
            └─► Deploy system-wide Vim config
```

## Idempotency

All tasks are designed to be **idempotent** - safe to run multiple times:

- **SSH keys**: Only added if not already present
- **Sudoers**: Only added if not already present
- **Packages**: Only installed if not already installed
- **Files**: Only copied if changed (Ansible handles this)

## Error Handling

The playbook handles errors gracefully:

- **Missing packages**: Fails with clear error message
- **Permission errors**: Fails if sudo access is insufficient
- **User not found**: Fails when trying to configure non-existent user
- **SSH errors**: Fails if SSH connection cannot be established

## Customization

### Adding New Packages

Edit `group_vars/all.yml`:

```yaml
debian_ubuntu_packages:
  - sudo
  - vim
  - your-new-package  # Add here
```

### Adding New Dotfiles

1. Add file to `files/` directory
2. Update `vim_config` role to copy the file
3. Add to the loop in the role's tasks

### Adding New Roles

1. Create role in `roles/` directory
2. Add role to `site.yml` in "Setup All Systems" play:

```yaml
roles:
  - ssh_setup
  - tools_setup
  - vim_config
  - your_new_role  # Add here
```

## Best Practices

1. **Test First**: Test playbook on a non-production system first
2. **Review Changes**: Use `--check` mode to preview changes:
   ```bash
   ansible-playbook playbooks/site.yml -i hosts.ini -l local --check
   ```
3. **Verbose Output**: Use `-v` for detailed output:
   ```bash
   ansible-playbook playbooks/site.yml -i hosts.ini -l local -v
   ```
4. **Backup First**: Always backup existing configurations before running
5. **Version Control**: Keep playbook and roles in version control

## See Also

- [architecture.md](architecture.md) - Overall system architecture
- [setup_local.md](setup_local.md) - Local deployment script
- [setup_remote.md](setup_remote.md) - Remote deployment script
- [setup_client.md](setup_client.md) - Client preparation script

