# Terraform — Infrastructure Provisioning

Provisions the AWS infrastructure for the TrustTunnel VPN: a custom VPC, public subnet, security group, EC2 instance, Elastic IP, and key pair — with remote state in S3 + DynamoDB.

For the project overview, architecture, and design rationale, see the [root README](../README.md). This file covers **how to run it** and the operational gotchas.

## Layout

```
terraform/
├── bootstrap/            # One-time: creates the S3 bucket + DynamoDB lock table (LOCAL state)
├── modules/
│   ├── vpc/              # Reusable network module (VPC, subnet, IGW, route table, SG)
│   └── ec2/              # Reusable compute module (EC2, Elastic IP, key pair)
└── environments/
    └── dev/             # Calls both modules; state stored remotely in S3
```

`bootstrap/` and `environments/dev/` are the two roots you run. The folders under `modules/` are never applied directly — `dev` calls them.

## Run order

The order matters: `bootstrap` creates the remote-state backend that `dev` depends on, so it must be applied first.

### 1. Bootstrap (run once, ever)

```bash
cd terraform/bootstrap
terraform init
terraform apply -var="state_bucket_name=<your-globally-unique-bucket-name>"
```

Note the bucket and lock-table names from the output — `dev` needs them.

### 2. Point dev's backend at that bucket

Edit `environments/dev/backend.tf` so `bucket` matches the name you just created.
(Terraform backends can't use variables, so this value is set by hand here.)

### 3. Provision the infrastructure

```bash
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars   # then fill in your real values
terraform init
terraform plan
terraform apply
```

## Required variables (dev)

Set these in `environments/dev/terraform.tfvars` (copy from `terraform.tfvars.example`):

| Variable | Example | Notes |
|---|---|---|
| `ssh_public_key`   | `ssh-ed25519 AAAA...` | Contents of your public key (e.g. `~/.ssh/id_ed25519.pub`) |
| `ssh_allowed_cidr` | `203.0.113.4/32`      | Your IP as a `/32`. Keep it scoped — don't open SSH to `0.0.0.0/0` |

`project_name` and `instance_type` have sensible defaults in `variables.tf` and don't need to be set unless you want to override them.

## Operational gotchas

These are the non-obvious things worth knowing before running or tearing down.

- **Bootstrap uses local state on purpose.** It creates the very bucket that remote state lives in, so it can't store its state remotely (chicken-and-egg). Its `terraform.tfstate` stays on disk and is git-ignored.

- **`backend.tf` bucket name is hardcoded.** Terraform doesn't allow variables in the backend block, so the bucket name in `dev/backend.tf` must be edited by hand to match bootstrap's output.

- **Instance type and region.** This project targets `eu-north-1`, which does **not** offer the `t2` instance family — use `t3.micro` (also the free-tier-eligible type there). Picking `t2.micro` fails at apply with an "Unsupported configuration" error.

- **`prevent_destroy` blocks teardown of the state resources.** The S3 bucket and DynamoDB table have `lifecycle { prevent_destroy = true }` as a safety net. To intentionally tear them down, remove those lines first (and empty the bucket), otherwise `terraform destroy` will refuse.

- **Tearing down vs. keeping costs low.** `terraform destroy` in `environments/dev` removes the EC2/EIP/VPC cleanly. The remote-state resources in `bootstrap` are left in place (and protected by `prevent_destroy`); they cost almost nothing.

## Outputs

`environments/dev` exposes the server's public IP, which the Ansible phase consumes as its inventory — see the [Ansible README](../ansible/README.md) (coming in Phase 2).
