#!/bin/bash
# scaffold.sh — creates the full Ansible project structure
# Run once from the project root: bash scaffold.sh

set -e

echo "Creating Ansible project structure..."

# Top level
mkdir -p ansible/{inventory,playbooks,group_vars/all}

# Role via ansible-galaxy
ansible-galaxy role init ansible/roles/trusttunnel

echo "Done. Structure created:"
tree ansible/ 2>/dev/null || find ansible/ -type d | sort
