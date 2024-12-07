# localconfig 4.0

The original localconfig repo contained the configuration files, tools and settings to get my own user environment onto a system. You know, so I feel at home :-)
This was a manual copy of files like .bashrc , .screenrc and .vimrc 
The problem is the manual part, need to figure out which directory vim is in (each version is using a different one such as vim74/ or vim81). Also the prerequisites need to be met, manually installing the tools like screen, vim and dependencies. Also user management (sudo) and SSH keys.

Well, no more I say :)

Everything is now in an Ansible Playbook with roles and the target systems can be Debian, Ubunutu or RHEL. It'll automatically detect and use the correct package manager and syntax.

Package version: 3.2.1 (2024/12 update)

## Instructions
Two items are not included in the git which need to be added:
- hosts.ini file
- discovered_ssh_keys directory

### Main Playbook: `site.yml`
#### Features:
1. **Dynamic Role Execution:**
   - Executes all roles in the `available_roles` list by default.
   - Allows users to specify which roles to execute.

2. **Inventory Sections:**
   - The `hosts.ini` file is organized into sections:
     - `[local]`: For local machine setup.
     - `[remote]`: For remote host setup (replace with actual remote host details).

### hosts.ini format:
<p class="has-line-data" data-line-start="0" data-line-end="2">[&lt;inventory name&gt;]<br>
<a href="http://xxx.xxx.xxx.xxx">xxx.xxx.xxx.xxx</a> ansible_user=&lt;name&gt; ansible_python_interpreter=/usr/bin/python3</p>


3. **Validation:**
   - Ensures that only valid roles (from `available_roles`) are executed.

4. **Ease of Use:**
   - Displays available roles and examples when the playbook is run.

---

### How to Use:

#### View Available Roles:
When you run the playbook, it will display a list of available roles along with examples for selecting specific roles. Example output:
```
Available roles:
- ssh_setup : makes sure all the user permissions and access stuff is arranged. It'll also dump all the SSH keys of the target system on the control system
- tools_setup : this will install the minimum set of tools I require on a system
- vim_config : this will deploy all the configuration files into the correct location. Also the VIM theme and colorscheme I like (<https://github.com/sjl/badwolf> and <https://github.com/vim-airline/vim-airline>). Currently the files are .bashrc , .vimrc , .screenrc and .curlrc

To run specific roles (locally or remotely), use: 
ansible-playbook playbooks/site.yml -i hosts.ini -e "selected_roles=['role_name_1','role_name_2']" -l local
Example (local): 
ansible-playbook playbooks/site.yml -i hosts.ini -e "selected_roles=['ssh_setup','vim_config']" -l local
Example (remote): 
ansible-playbook playbooks/site.yml -i hosts.ini -e "selected_roles=['ssh_setup','vim_config']" -l remote
```

#### Run All Roles (Default):
To execute all roles in sequence:
- **Locally:**
  ```bash
  ansible-playbook playbooks/site.yml -i hosts.ini -l local
  ```
- **Remotely:**
  ```bash
  ansible-playbook playbooks/site.yml -i hosts.ini -l remote
  ```

#### Run Specific Roles:
To execute specific roles, use the `selected_roles` variable:
- **Locally:**
  ```bash
  ansible-playbook playbooks/site.yml -i hosts.ini -e "selected_roles=['ssh_setup','tools_setup']" -l local
  ```
- **Remotely:**
  ```bash
  ansible-playbook playbooks/site.yml -i hosts.ini -e "selected_roles=['ssh_setup','tools_setup']" -l remote
  ```

#### setup_local.sh

For convenience, I've included a bash script to deploy on a local system. So, besides ansible install and Python3 install, the only thing to do is 'git clone' this repo, add the ansible_user to sudoers en run the setup_local.sh

---

### Adding New Roles:
1. Add the new role to the `roles/` directory.
2. Include the role name in the `available_roles` list in `site.yml`.
3. The new role will automatically be recognized and can be run dynamically.

---

### Notes:
- Ensure that the roles you want to run are included in the `available_roles` list in `site.yml`.
- The playbook validates the roles specified in `selected_roles` to avoid errors.
- Change all.yml to contain the name of the standard user (which will be the ansible_user) on the target system

### Note
in RHEL there is no screen, they depprecated it in favor of tmux. Still need to convert my .screenrc to tmux config for RHEL usage only.

## Structure

```
localconfig/
│
├── group_vars/ 
│ └── all.yml
|
├── playbooks/
│ └── site.yml
│
├── discovered_ssh_keys/
│   ├── host1_keys.txt
│   ├── host2_keys.txt
│   └── ... (other files containing lists of public SSH keys from target systems)
│
├── roles/
│   ├── ssh_setup/
│   │   └── tasks/
│   │     └── main.yml
│   ├── tools_setup/
│   │   └── tasks/
│   │     └── main.yml
│   └── vim__setup/
│   │   └── tasks/
│   │     └── main.yml
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
├── README.md
├── setup_local.sh
└── hosts.ini
```

