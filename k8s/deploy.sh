#!/bin/bash
# deploy.sh — deploys the full observability stack onto k3s.
#
# Prerequisites:
#   1. k3s is running (ansible-playbook playbooks/k3s.yml)
#   2. kubeconfig-k3s.yaml exists in ansible/ (fetched by the k3s role)
#   3. You have helm and kubectl installed locally
#
# Usage (from repo root):
#   export KUBECONFIG="$(pwd)/ansible/kubeconfig-k3s.yaml"
#   bash k8s/deploy.sh <VPN_PRIVATE_IP> <GRAFANA_DOMAIN> <CLOUDFLARE_API_TOKEN>
#
# Example:
#   bash k8s/deploy.sh 10.20.1.42 grafana.usain.xyz cf-token-here

set -euo pipefail

VPN_PRIVATE_IP="${1:?Usage: deploy.sh <VPN_PRIVATE_IP> <GRAFANA_DOMAIN> <CLOUDFLARE_API_TOKEN>}"
GRAFANA_DOMAIN="${2:?Usage: deploy.sh <VPN_PRIVATE_IP> <GRAFANA_DOMAIN> <CLOUDFLARE_API_TOKEN>}"
CF_API_TOKEN="${3:?Usage: deploy.sh <VPN_PRIVATE_IP> <GRAFANA_DOMAIN> <CLOUDFLARE_API_TOKEN>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Phase 4: Deploying observability stack ==="
echo "VPN private IP: ${VPN_PRIVATE_IP}"
echo "Grafana domain: ${GRAFANA_DOMAIN}"

# --- 1. cert-manager ---
echo ""
echo "--- Installing cert-manager ---"
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true \
  --wait

# Create the Cloudflare API token secret (imperatively — never committed in plaintext)
kubectl create secret generic cloudflare-api-token \
  --namespace cert-manager \
  --from-literal=api-token="${CF_API_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Applying ClusterIssuer..."
kubectl apply -f "${SCRIPT_DIR}/cert-manager/cluster-issuer.yaml"

# --- 2. kube-prometheus-stack ---
echo ""
echo "--- Installing kube-prometheus-stack ---"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

# Render values with actual IPs/domains
sed -e "s/<VPN_PRIVATE_IP>/${VPN_PRIVATE_IP}/g" \
    -e "s/<GRAFANA_DOMAIN>/${GRAFANA_DOMAIN}/g" \
    "${SCRIPT_DIR}/prometheus-grafana/values.yaml" > /tmp/prometheus-values-rendered.yaml

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f /tmp/prometheus-values-rendered.yaml \
  --wait --timeout 10m

rm -f /tmp/prometheus-values-rendered.yaml

# Apply the Grafana dashboard ConfigMap (sidecar auto-discovers it — no helm
# upgrade required when only the dashboard JSON changes in the future).
echo ""
echo "--- Applying Grafana dashboard ConfigMap ---"
kubectl apply -f "${SCRIPT_DIR}/prometheus-grafana/dashboards/trusttunnel-dashboard-cm.yaml"

# --- 3. Synthetic check CronJob ---
echo ""
echo "--- Deploying synthetic check CronJob ---"

# Get the VPN public domain from the existing Ansible defaults
VPN_DOMAIN="${VPN_DOMAIN:-trustt.usain.xyz}"
sed "s/<VPN_PUBLIC_DOMAIN>/${VPN_DOMAIN}/g" \
  "${SCRIPT_DIR}/synthetic-check/cronjob.yaml" | kubectl apply -f -

echo ""
echo "=== Done! ==="
echo ""
echo "Grafana will be available at: https://${GRAFANA_DOMAIN}"
echo "  (after DNS propagates and cert-manager issues the certificate)"
echo ""
echo "Default Grafana credentials: admin / changeme-on-first-login"
echo "Prometheus is scraping: ${VPN_PRIVATE_IP}:1987"
echo ""
echo "Dashboard: Grafana → Dashboards → TrustTunnel → TrustTunnel VPN Overview"
