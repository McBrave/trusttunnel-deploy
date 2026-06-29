# Ansible — TrustTunnel VPN Configuration

Automates the full configuration of a TrustTunnel VPN endpoint on an Ubuntu EC2 instance provisioned by Terraform. A single playbook run takes a bare server to a fully running, TLS-secured VPN with DNS configured in Cloudflare.

## What it does

1. **Prerequisites** — creates the install directory and installs base dependencies
2. **Install** — downloads the TrustTunnel binary via the official install script
3. **DNS** — creates the DNS A record in Cloudflare automatically (idempotent — skips if record already exists)
4. **Certbot** — obtains a Let's Encrypt TLS certificate via standalone mode
5. **Configure** — renders `vpn.toml`, `hosts.toml`, and `credentials.toml` from Jinja2 templates
6. **Service** — installs and starts TrustTunnel as a hardened systemd service, then prints the client deeplink

## Prerequisites

- Ansible 2.12+ installed on your control machine (WSL on Windows)
- `community.general` collection: `ansible-galaxy collection install community.general`
- Terraform must have been applied first — the EC2 instance must exist
- DNS for your domain must be managed by Cloudflare
- Your SSH private key must be accessible at the path in `ansible.cfg`

## Quick start

```bash
# 1 — copy and fill in secrets
cp vpn_secrets.yml.example vpn_secrets.yml
# edit vpn_secrets.yml with real values

# 2 — encrypt secrets with Ansible Vault
ansible-vault encrypt vpn_secrets.yml
# you will be prompted to set a vault password
# save this password somewhere safe — you need it to run the playbook

# 3 — store vault password locally for convenience
echo "your-vault-password" > vault_pass.txt
# vault_pass.txt is git-ignored — never commit it

# 4 — generate inventory from Terraform output
./inventory/generate-inventory.sh

# 5 — run the playbook
ansible-playbook playbooks/site.yml
```

## Secrets

All sensitive values live in `vpn_secrets.yml` (Ansible Vault encrypted). Copy the example file and fill in real values:

```yaml
# vpn_secrets.yml
trusttunnel_client_username: "your-vpn-username"
trusttunnel_client_password: "your-strong-password"
cloudflare_api_token: "your-cloudflare-api-token"
cloudflare_zone_id: "your-cloudflare-zone-id"
```

### Cloudflare API token permissions

Create a token at Cloudflare → My Profile → API Tokens using the **Edit zone DNS** template. Set:
- Scope: specific zone → your domain only
- Permissions: `Zone:DNS:Edit` + `Zone:Zone:Read`

## Configuration

Non-sensitive defaults live in `roles/trusttunnel/defaults/main.yml`. The two values you must change before running:

```yaml
trusttunnel_domain: "vpn.yourdomain.com"       # your real subdomain
trusttunnel_letsencrypt_email: "you@email.com"  # for Let's Encrypt expiry notices
```

## Role structure

```
roles/trusttunnel/
├── defaults/
│   └── main.yml              # all non-sensitive role variables
├── handlers/
│   └── main.yml              # restart/reload triggers
├── tasks/
│   ├── main.yml              # import orchestrator (runs tasks in order)
│   ├── prerequisites.yml     # base dependencies and directory setup
│   ├── install.yml           # TrustTunnel binary install (idempotent)
│   ├── dns.yml               # Cloudflare DNS A record (idempotent)
│   ├── certbot.yml           # Let's Encrypt TLS certificate
│   ├── configure.yml         # render TOML config files from templates
│   └── service.yml           # systemd enable/start + client deeplink
├── templates/
│   ├── vpn.toml.j2           # tunnel routing and protocol config
│   ├── hosts.toml.j2         # TLS certificate paths and domain
│   ├── credentials.toml.j2   # client username/password (mode 0600)
│   └── trusttunnel.service.j2 # systemd unit with hardening
└── meta/
    └── main.yml              # role metadata
```

## Running specific phases

Tags let you re-run individual phases without running everything:

```bash
# re-render configs and restart service only
ansible-playbook playbooks/site.yml --tags configure,service

# re-run certbot only (e.g. after cert expires)
ansible-playbook playbooks/site.yml --tags certbot

# re-run DNS only
ansible-playbook playbooks/site.yml --tags dns
```

## Security decisions

| Decision | Reason |
|---|---|
| Secrets encrypted with Ansible Vault | Safe to commit to public repo as ciphertext |
| `credentials.toml` mode `0600` | Only root can read VPN credentials on the server |
| `no_log: true` on credentials task | Password never appears in Ansible output or CI logs |
| Certbot standalone mode | No nginx/apache needed — TrustTunnel owns port 443 |
| Metrics bound to `127.0.0.1` | Prometheus endpoint not exposed to the internet |
| Systemd `NoNewPrivileges`, `ProtectSystem` | Limits blast radius if process is compromised |
| Cloudflare token scoped to one zone | Token can only touch DNS on the specific domain |

## Inventory

`inventory/hosts.ini` is git-ignored because it contains the live EC2 IP which changes on every `terraform apply`. Regenerate it after any infrastructure change:

```bash
./inventory/generate-inventory.sh
```

This reads `vpn_public_ip` from Terraform output and writes `hosts.ini` automatically.

## Important notes

- **DNS must propagate before certbot runs.** The playbook waits 30 seconds after creating the DNS record but Let's Encrypt may still fail if propagation is slow. Re-run with `--tags certbot` if this happens.
- **Port 80 must be open** in the EC2 security group for the ACME HTTP-01 challenge. Terraform handles this.
- **Port 443 TCP and UDP** must be open — TCP for TLS connections, UDP for QUIC.
- The playbook is fully idempotent — safe to re-run at any time without side effects.
