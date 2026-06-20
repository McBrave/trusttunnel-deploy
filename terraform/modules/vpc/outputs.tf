output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet. Consumed by modules/ec2."
  value       = aws_subnet.public.id
}
