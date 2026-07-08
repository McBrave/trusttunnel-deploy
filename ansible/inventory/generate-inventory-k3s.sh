#!/bin/bash
# generate-inventory-k3s.sh — extends hosts.ini with the [k3s] group.
#
# Run this after `terraform apply` to pick up the k3s node's IP.
# Appends to the existing hosts.ini (run generate-inventory.sh first).
#
# Usage (from the ansible/ directory):
#   ./inventory/generate-inventory.sh        # VPN group
#   ./inventory/generate-inventory-k3s.sh    # k3s group (appends)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "${SCRIPT_DIR}/../../terraform/environments/dev" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/hosts.ini"

if [[ ! -f "${INVENTORY_FILE}" ]]; then
  echo "ERROR: ${INVENTORY_FILE} does not exist. Run generate-inventory.sh first."
  exit 1
fi

echo "Reading k3s Terraform output from: ${TERRAFORM_DIR}"

K3S_IP=$(terraform -chdir="${TERRAFORM_DIR}" output -raw k3s_public_ip 2>/dev/null)

if [[ -z "${K3S_IP}" ]]; then
  echo "ERROR: Could not get k3s_public_ip from Terraform output."
  echo "Make sure you have run 'terraform apply' in ${TERRAFORM_DIR} first."
  exit 1
fi

echo "k3s IP: ${K3S_IP}"

# Remove any existing [k3s] block to make this idempotent
sed -i '/^\[k3s\]/,/^$/d' "${INVENTORY_FILE}"

# Append the k3s group
cat >> "${INVENTORY_FILE}" << EOF

[k3s]
k3s-node ansible_host=${K3S_IP}

[k3s:vars]
ansible_user=ubuntu
EOF

echo "k3s group appended to: ${INVENTORY_FILE}"
