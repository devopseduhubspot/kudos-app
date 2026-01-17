# ==============================================================================
# TERRAFORM OUTPUTS
# ==============================================================================
# These outputs provide important information after deployment
# Used by Ansible for inventory and configuration management
# ==============================================================================

# Load Balancer Information
output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}

# VPC Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

# Auto Scaling Group Information
output "autoscaling_group_name" {
  description = "Name of the auto scaling group"
  value       = aws_autoscaling_group.web_servers.name
}

output "autoscaling_group_arn" {
  description = "ARN of the auto scaling group"
  value       = aws_autoscaling_group.web_servers.arn
}

# Security Group Information
output "web_security_group_id" {
  description = "ID of the web servers security group"
  value       = aws_security_group.web_servers.id
}

output "load_balancer_security_group_id" {
  description = "ID of the load balancer security group"
  value       = aws_security_group.load_balancer.id
}

# SSH Key Information
output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = var.key_pair_name != "" ? var.key_pair_name : aws_key_pair.main[0].key_name
}

output "private_key_path" {
  description = "Path to the private key file (if generated)"
  value       = var.key_pair_name == "" ? local_file.private_key[0].filename : "Using existing key pair: ${var.key_pair_name}"
}

# Instance Information
output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.web_server.id
}

output "instance_type" {
  description = "Instance type used for web servers"
  value       = var.instance_type
}

# Ansible Inventory Information
output "ansible_inventory_command" {
  description = "Command to generate Ansible inventory from AWS"
  value       = "aws ec2 describe-instances --region ${var.aws_region} --filters 'Name=tag:AnsibleGroup,Values=webservers' --query 'Reservations[*].Instances[*].[PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' --output table"
}

# Useful Commands
output "ssh_command_example" {
  description = "Example SSH command to connect to instances"
  value       = "ssh -i ${var.key_pair_name == "" ? local_file.private_key[0].filename : "${var.key_pair_name}.pem"} ec2-user@<instance-public-ip>"
}

output "ansible_ping_command" {
  description = "Command to test Ansible connectivity"
  value       = "ansible webservers -m ping -i inventory/aws_ec2.yml"
}

# Infrastructure Summary
output "infrastructure_summary" {
  description = "Summary of created infrastructure"
  value = {
    vpc_cidr           = var.vpc_cidr
    availability_zones = local.availability_zones
    min_servers        = var.min_servers
    max_servers        = var.max_servers
    instance_type      = var.instance_type
    application_port   = local.app_port
    load_balancer_dns  = aws_lb.main.dns_name
    region            = var.aws_region
    environment       = var.environment
    created_at        = timestamp()
  }
}