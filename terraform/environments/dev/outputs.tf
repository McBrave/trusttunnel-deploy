output "vpn_public_ip" {
  description = "Stable public IP of the TrustTunnel endpoint. Ansible reads this for its dynamic inventory."
  value       = module.ec2.public_ip
}

output "instance_id" {
  description = "EC2 instance ID, useful for SSM/console lookups."
  value       = module.ec2.instance_id
}

output "vpc_id" {
  description = "VPC ID, useful for debugging or extending the network later."
  value       = module.vpc.vpc_id
}
