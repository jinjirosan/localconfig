# Localconfig Architecture

## Overview

Localconfig is an Ansible-based configuration management system that automates the deployment of a personalized development environment across local and remote systems. It supports Debian/Ubuntu, RHEL/CentOS, and FreeBSD distributions, automatically detecting the OS and using the appropriate package manager and tools.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Localconfig Repository                      │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Scripts    │  │  Playbooks   │  │    Roles     │         │
│  │              │  │              │  │              │         │
│  │ setup_local  │  │   site.yml   │  │ ssh_setup    │         │
│  │ setup_remote │  │              │  │ tools_setup   │         │
│  │ setup_client │  │              │  │ vim_config    │         │
│  │              │  │              │  │ login_setup   │         │
│  │              │  │              │  │ desktop_apps_ │         │
│  │              │  │              │  │   setup       │         │
│  │              │  │              │  │ security_setup│         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  Config      │  │   Files     │  │   Vars       │         │
│  │              │  │             │  │              │         │
│  │ ansible.cfg  │  │  dotfiles   │  │ group_vars/  │         │
│  │ hosts.ini    │  │  vim files  │  │   all.yml    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                             │
        ▼                                             ▼
┌──────────────┐                            ┌──────────────┐
│ Local Host   │                            │ Remote Host  │
│              │                            │              │
│ setup_local  │                            │ setup_client │
│     │        │                            │     │        │
│     └────────┼────────────────────────────┼─────┘        │
│              │                            │              │
│              │      SSH Connection        │              │
│              │◄────────────────────────────┤              │
│              │                            │              │
│              │    Ansible Playbook         │              │
│              │───────────────────────────►│              │
│              │                            │              │
└──────────────┘                            └──────────────┘
```

## Component Overview

### 1. Setup Scripts

Three bash scripts handle different deployment scenarios:

- **`setup_local.sh`**: Deploys localconfig to the local machine
- **`setup_remote.sh`**: Deploys localconfig to remote VMs (runs on control host)
- **`setup_client.sh`**: Prepares a fresh VM for Ansible management (runs on target VM)

### 2. Ansible Playbook

**`playbooks/site.yml`** orchestrates the entire deployment process:

- **Initial Setup Play**: Configures sudoers for target users
- **Setup All Systems Play**: Executes all roles in sequence

### 3. Ansible Roles

Six roles handle specific aspects of the configuration:

#### `ssh_setup`
- Ensures SSH key pair exists on control machine
- Installs `sshpass` for password-based SSH setup (Debian/Ubuntu)
- Copies public key to target systems
- Backs up existing SSH keys to `discovered_ssh_keys/` directory

#### `tools_setup`
- Detects OS (Debian/Ubuntu vs RHEL vs FreeBSD) and selects package manager
- Installs essential development tools system-wide
- Configures sudo access with NOPASSWD for ansible user
- Verifies package installation

#### `vim_config`
- Dynamically detects Vim version
- Deploys dotfiles (`.vimrc`, `.bashrc`, `.screenrc`, `.curlrc`) to user home directories
- Installs Badwolf color scheme and vim-airline plugin
- Deploys all Vim autoload scripts and plugins to system-wide directories

#### `login_setup`
- Configures MOTD (Message of the Day) with ASCII art hostname banner
- Sets up SSH login banners with security warning
- Dynamic System Information (hostname, OS, kernel, IP addresses with reverse DNS) displayed in `.bashrc` on login
- OS-aware deployment (Debian/Ubuntu uses `/etc/motd`, RHEL uses `/etc/issue`, FreeBSD uses `/etc/motd.template`)
- Optional MOTD replacement (user can preview and choose to keep existing)
- Ensures SSH service restarts after banner configuration

#### `desktop_apps_setup` (optional)
- Installs desktop applications: Brave Browser, LibreOffice, VLC
- Detects desktop environment (MATE, GNOME, XFCE, KDE)
- OS-specific installation (Debian/Ubuntu, RHEL/CentOS, FreeBSD)
- Uses official repositories for Brave Browser with proper GPG key management
- Interactive prompts in setup scripts for each application
- Only runs when enabled via interactive prompts in setup scripts

#### `security_setup` (optional)
- Deploys stateful firewall with default-deny inbound/outbound filtering
- **Linux (Debian/Ubuntu, RHEL)**: nftables firewall (disables/masks firewalld on RHEL)
- **FreeBSD**: PF firewall
- Allows SSH only from configurable subnets (CIDR ranges)
- Allows DNS/DHCP and selected outbound (HTTP/HTTPS, SSH)
- Logs outbound drops with fixed prefixes for visibility
- Configures log limits: 500MB total size, 14-day retention
- Only runs when enabled via interactive prompts in setup scripts

## Data Flow

### Local Deployment Flow

```
User runs setup_local.sh
    │
    ├─► Checks/installs Ansible
    ├─► Creates/updates hosts.ini
    ├─► Interactive user selection
    │   ├─► Option 1: Current user + root
    │   ├─► Option 2: Specific user(s) - space-separated
    │   └─► Option 3: All users
    ├─► Additional sudo users selection
    ├─► Desktop applications setup prompts (optional)
    ├─► Firewall configuration prompts (optional)
    │
    └─► Executes playbooks/site.yml
        │
        ├─► Initial Setup Play
        │   └─► Adds target_user(s) to sudoers
        │
        └─► Setup All Systems Play
            ├─► ssh_setup role
            ├─► tools_setup role
            ├─► login_setup role
            ├─► security_setup role (if enabled)
            └─► vim_config role
```

### Remote Deployment Flow

```
Step 1: On Target VM
User runs setup_client.sh
    │
    ├─► Detects OS
    ├─► Installs prerequisites (git, sudo, sshpass, python3)
    ├─► Creates ansible user
    ├─► Sets up SSH directory
    ├─► Adds control host's SSH key
    └─► Configures NOPASSWD sudo for ansible user

Step 2: On Control Host
User runs setup_remote.sh <vm_ip>
    │
    ├─► Validates Ansible installation
    ├─► Tests SSH connectivity
    ├─► Updates hosts.ini
    ├─► Interactive user selection
    │   ├─► Option 1: Ansible user + root
    │   ├─► Option 2: Specific user(s) - space-separated
    │   └─► Option 3: All users
    ├─► Additional sudo users selection
    ├─► MOTD preview and replacement option
    ├─► Desktop applications setup prompts (optional)
    ├─► Firewall configuration prompts (optional)
    │
    └─► Executes playbooks/site.yml via SSH
        │
        ├─► Initial Setup Play
        │   └─► Adds target_user(s) to sudoers
        │
        └─► Setup All Systems Play
            ├─► ssh_setup role
            ├─► tools_setup role
            ├─► login_setup role
            ├─► security_setup role (if enabled)
            └─► vim_config role
```

## User Configuration Modes

The system supports three user configuration modes:

### Mode 1: Default (Ansible User + Root)
- **Sudoers**: `ansible_user` + `target_user` (if different from ansible_user)
- **Dotfiles**: `ansible_user` + `target_user` + `root`
- **Tools**: System-wide installation

### Mode 2: Specific User(s)
- **Sudoers**: `ansible_user` + all specified users (space-separated)
- **Dotfiles**: `ansible_user` + all specified users + `root`
- **Tools**: System-wide installation

### Mode 3: All Users
- **Sudoers**: Only `ansible_user` (skips adding "all" to sudoers)
- **Dotfiles**: `ansible_user` + all users in `/home/` + `root`
- **Tools**: System-wide installation

## File Structure

```
localconfig/
├── docs/                    # Documentation
├── files/                   # Configuration files to deploy
│   ├── .vimrc              # Vim configuration
│   ├── .bashrc              # Bash configuration
│   ├── .screenrc            # Screen configuration
│   ├── .curlrc              # Curl configuration
│   ├── colors/              # Vim color schemes
│   ├── plugin/              # Vim plugins
│   └── autoload/            # Vim autoload scripts
├── group_vars/              # Ansible variables
│   └── all.yml              # Package lists and user config
├── playbooks/               # Ansible playbooks
│   └── site.yml             # Main playbook
├── roles/                   # Ansible roles
│   ├── ssh_setup/           # SSH configuration role
│   ├── tools_setup/         # Tools installation role
│   ├── vim_config/          # Vim configuration role
│   ├── login_setup/         # MOTD and login banners role
│   ├── desktop_apps_setup/  # Optional desktop applications role
│   └── security_setup/      # Optional firewall role
├── ansible.cfg              # Ansible configuration
├── setup_local.sh           # Local deployment script
├── setup_remote.sh          # Remote deployment script
├── setup_client.sh          # Client preparation script
└── README.md                # Project README
```

## Key Design Decisions

1. **OS Detection**: Automatic detection of Debian/Ubuntu vs RHEL vs FreeBSD to use appropriate package managers and tools
2. **Vim Version Detection**: Dynamic detection of Vim version to deploy to correct system directories
3. **User Flexibility**: Support for single user, multiple users, or all users
4. **Idempotency**: All tasks are idempotent - safe to run multiple times
5. **SSH Key Backup**: Automatic backup of existing SSH keys before modification
6. **Sudo Configuration**: Separate handling for single users vs "all users" to avoid adding invalid entries
7. **Optional Security**: Firewall configuration is optional and interactive, allowing users to choose when to enable it
8. **Log Visibility**: Firewall logs are integrated into login display (`.bashrc`) showing top blocked destinations
9. **Dynamic System Info**: System information (hostname, OS, kernel, IPs) displayed dynamically in `.bashrc` on every login, always up-to-date
10. **Ansible User Cleanup**: After deployment, ansible user is automatically disabled (sudo removed, SSH keys moved) via delayed background script for security hardening
11. **Non-Interactive Execution**: All questions asked upfront in setup scripts; playbook runs completely non-interactively

## Dependencies

- **Ansible**: 2.9+ (installed automatically by setup scripts)
- **Python 3**: Required on target systems
- **SSH**: For remote deployments
- **Sudo**: Required for privilege escalation
- **nftables** (Linux): Installed automatically by `security_setup` role when enabled
- **PF** (FreeBSD): Built-in, configured by `security_setup` role when enabled

## Security Considerations

1. **SSH Keys**: Uses SSH key-based authentication for remote access
2. **Sudo Access**: Configures NOPASSWD sudo for ansible user (required for automation)
3. **SSH Key Backup**: Backs up existing SSH keys before modification
4. **User Validation**: Validates user existence before configuration
5. **Optional Firewall**: `security_setup` role provides stateful firewall with default-deny policies
   - Restricts SSH access to configurable subnets
   - Logs outbound connection attempts for visibility
   - Configures log retention limits to prevent disk fill

## Extension Points

The architecture supports easy extension:

1. **New Roles**: Add roles to `roles/` directory and include in `site.yml`
2. **New Tools**: Add packages to `group_vars/all.yml`
3. **New Dotfiles**: Add files to `files/` directory and reference in `vim_config` role
4. **New OS Support**: Add OS detection logic in `tools_setup` role

