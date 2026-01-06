
#!/bin/bash
# Get the currently logged-in user
CURRENT_USER=$(whoami)

# Ensure Ansible is installed
if ! command -v ansible > /dev/null; then
  echo "Ansible is not installed. Installing Ansible..."
  if [ -f /etc/debian_version ]; then
    sudo apt update && sudo apt install ansible -y
  elif [ -f /etc/redhat-release ]; then
    sudo yum install epel-release -y && sudo yum install ansible -y
  else
    echo "Unsupported OS. Please install Ansible manually."
    exit 1
  fi
fi

# Navigate to the ansible_localconfig directory
cd "$(dirname "$0")" || exit

# Ensure hosts.ini exists and is correctly configured
if [ ! -f hosts.ini ]; then
  echo "[local]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3" > hosts.ini
  echo "Generated hosts.ini with a [local] section."
fi

# Run the playbook targeting the [local] group
# Check if the current user is already in sudoers
if ! sudo -n true 2>/dev/null; then
  echo "$CURRENT_USER is not in sudoers. Using root for initial setup."
  ansible-playbook playbooks/site.yml -i hosts.ini -l local --extra-vars "ansible_user=root target_user=$CURRENT_USER" --ask-become-pass
else
  echo "$CURRENT_USER is in sudoers. Proceeding with normal setup."
  # Always pass ansible_user so files go to the current user's home, not root's
  ansible-playbook playbooks/site.yml -i hosts.ini -l local --extra-vars "ansible_user=$CURRENT_USER" --ask-become-pass
fi

echo "Running the Ansible playbook for the local setup..."

# Notify the user
if [ $? -eq 0 ]; then
  echo "Local setup completed successfully!"
else
  echo "An error occurred during local setup. Please check the output above for details."
fi
