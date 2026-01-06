# Localconfig Documentation

Welcome to the Localconfig documentation! This directory contains comprehensive documentation for understanding and using the localconfig system.

## Documentation Index

### [Architecture Documentation](architecture.md)
**Start here** for an overview of the system architecture, component relationships, and how everything fits together.

- System architecture diagrams
- Component overview
- Data flow diagrams
- File structure
- Design decisions
- Extension points

### Script Documentation

#### [setup_local.sh](setup_local.md)
Documentation for local machine deployment.

- Purpose and prerequisites
- Usage examples
- User selection options
- Configuration applied
- Troubleshooting

#### [setup_remote.sh](setup_remote.md)
Documentation for remote VM deployment.

- Purpose and prerequisites
- Usage examples
- Integration with setup_client.sh
- SSH connectivity
- Troubleshooting

#### [setup_client.sh](setup_client.md)
Documentation for preparing remote VMs.

- Purpose and prerequisites
- Interactive and non-interactive modes
- SSH key selection
- Configuration applied
- Troubleshooting

### [Playbooks and Roles](playbooks.md)
Documentation for Ansible playbooks and roles.

- Main playbook structure
- Role: ssh_setup
- Role: tools_setup
- Role: vim_config
- Variables and customization
- Execution flow

## Quick Start Guide

### For Local Machine Setup

1. Read: [setup_local.md](setup_local.md)
2. Run: `./setup_local.sh`
3. Select user configuration option
4. Done!

### For Remote VM Setup

1. **On Remote VM**: Read [setup_client.md](setup_client.md) and run `./setup_client.sh`
2. **On Control Host**: Read [setup_remote.md](setup_remote.md) and run `./setup_remote.sh <vm_ip>`
3. Select user configuration option
4. Done!

## Documentation Structure

```
docs/
├── README.md              # This file - documentation index
├── architecture.md         # System architecture overview
├── setup_local.md         # Local deployment script docs
├── setup_remote.md        # Remote deployment script docs
├── setup_client.md       # Client preparation script docs
└── playbooks.md          # Playbook and roles documentation
```

## Getting Help

### Understanding the System

1. **New to localconfig?** Start with [architecture.md](architecture.md)
2. **Want to deploy locally?** Read [setup_local.md](setup_local.md)
3. **Want to deploy remotely?** Read [setup_client.md](setup_client.md) and [setup_remote.md](setup_remote.md)
4. **Want to customize?** Read [playbooks.md](playbooks.md)

### Common Tasks

**Deploy to local machine:**
- See [setup_local.md](setup_local.md) - Basic Usage section

**Deploy to remote VM:**
- See [setup_remote.md](setup_remote.md) - Usage section
- Don't forget to run [setup_client.sh](setup_client.md) first!

**Configure multiple users:**
- See [setup_local.md](setup_local.md) - Option 2: Specific User(s)
- See [setup_remote.md](setup_remote.md) - Option 2: Specific User(s)

**Understand what gets configured:**
- See [playbooks.md](playbooks.md) - Configuration Applied sections

**Troubleshoot issues:**
- Each script documentation has a Troubleshooting section
- Check [architecture.md](architecture.md) for system overview

## Documentation Conventions

- **Code blocks**: Show commands and configuration examples
- **Example Output**: Shows what you should see when running commands
- **Troubleshooting**: Common issues and solutions
- **Best Practices**: Recommended approaches
- **See Also**: Links to related documentation

## Contributing

When updating documentation:

1. Keep examples current and accurate
2. Update all related documentation when making changes
3. Test examples before documenting
4. Use consistent formatting
5. Link between related documents

## Version

This documentation corresponds to **localconfig 4.0** (2024/12 update).

For the latest version information, see the main [README.md](../README.md).

