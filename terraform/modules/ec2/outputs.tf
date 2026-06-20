output "public_ip" {
  description = "Stable Elastic IP of the VPN endpoint. Consumed by Ansible's dynamic inventory."
  value       = aws_eip.trusttunnel.public_ip
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.trusttunnel.id
}

output "security_group_id" {
  description = "Security group ID attached to the instance."
  value       = aws_security_group.trusttunnel.id
}
