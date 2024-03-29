# localconfig 2.0

The original localconfig repo contained the configuration files, tools and settings to get my own user environment onto a system. You know, so I feel at home :-)
This was a manual copy of files like .bashrc , .screenrc and .vimrc 
The problem is the manual part, need to figure out which directory vim is in (each version is using a different one such as vim74/ or vim81). Also the prerequisites need to be met, manually installing the tools like screen, vim and dependencies. Also user management (sudo) and SSH keys.

Well, no more I say :)

Everything is now in Ansbile Playbooks and the target systems can be Debian, Ubunutu or RHEL. It'll automatically detect and use the correct package manager and syntax.

Package version: 2.1 (2023 update)

## Pre-requisites
- Deploy a fresh new target system with one of the three OS's. Just a base install but make sure to check Python is installed. If it's Python3, note the path (which Python) to add to the hosts.ini later.
Have your own 'control' system with Ansible installed. Fetch this repo.

- Create a hosts.ini (see below for placement to contain the target systems IP and standard user (playbook will take care of sudoers).
### hosts.ini format:
<p class="has-line-data" data-line-start="0" data-line-end="2">[&lt;inventory name&gt;]<br>
<a href="http://xxx.xxx.xxx.xxx">xxx.xxx.xxx.xxx</a> ansible_user=&lt;name&gt; ansible_python_interpreter=/usr/bin/python3</p>

- Change user_vars.yml to contain the name of that standard user on the target system

### Note
in RHEL there is no screen, they depprecated it in favor of tmux. Still need to convert my .screenrc to tmux config.

## Structure

There are three playbooks that need to be run sequentially the 1st time. Each will take care of a certain task. I've split these tasks as sometimes I only need to execute one specific task.

- `1_ssh_setup.yml` : makes sure all the user permissions and access stuff is arranged. It'll also dump all the SSH keys of the target system on the control system
- `2_tools_setup.yml` : this will install all the tools
- `3_localconfig_setup.yml` : this will deploy all the configuration files into the correct location. Also the VIM theme and colorscheme I like (<https://github.com/sjl/badwolf> and <https://github.com/vim-airline/vim-airline>). Currently the files are .bashrc , .vimrc , .screenrc and .curlrc

```
localconfig/
│
├── group_vars/ 
│ └── user_vars.yml
|
├── playbooks/
│   ├── 1_ssh_setup.yml
│   ├── 2_tools_setup.yml
│   └── 3_localconfig_setup.yml
│
├── discovered_ssh_keys/
│   ├── host1_keys.txt
│   ├── host2_keys.txt
│   └── ... (other files containing lists of public SSH keys from target systems)
│
├── roles/
│   ├── role1/
│   │   ├── tasks/
│   │   ├── handlers/
│   │   └── ... (other directories/files related to this role)
│   └── ... (other roles)
│
├── files/
│   ├── .vimrc
│   ├── .screenrc
│   ├── .bashrc
│   ├── .curlrc
│   │
│   ├── colors/
│   │   └── badwolf.vim
│   │
│   ├── plugin/
│   │   ├── airline.vim
│   │   └── airline-themes.vim
│   │
│   └── autoload/
│       └── ... (all the autoload files and directories for vim)
│
├── ansible.cfg
│
└── hosts.ini
```



## Installation

1. **To run the `1_ssh_setup.yml` playbook:**

Since this is the initial setup and you're using password authentication to set up the key-based authentication, you'd use the `--ask-pass` option to enter the ansible_user password (the user on the target system):


> ansible-playbook -i hosts.ini playbooks/1_ssh_setup.yml --ask-pass


This will prompt you for the SSH password for the hosts you're connecting to.

2. **To run the `2_tools_setup.yml` playbook:**

Since this needs elevated privileges to run the package installs we need to add the ansible_user to sudoers (ansible_user is in a separate user_vars.yml). Use the `--ask-become-pass` and enter the ROOT password when asked:


> ansible-playbook -i hosts.ini playbooks/2_tools_setup.yml --ask-become-pass


3. **To run the `3_localconfig_setup.yml` playbook:**

After setting up key-based authentication with the previous playbook, you don't need the `--ask-pass` option anymore. So, you can run:


> ansible-playbook -i hosts.ini playbooks/3_localconfig_setup.yml


Just remember to always specify your inventory file using the `-i` option so that Ansible knows which hosts to target for the playbook execution.
