# ==============================================================================
# TERRAFORM VARIABLES FOR EC2 DEPLOYMENT
# ==============================================================================
# These variables allow customization of the infrastructure
# Perfect for teaching different deployment scenarios
# ==============================================================================

variable "app_name" {
  description = "Name of the application (used for resource naming)"
  type        = string
  default     = "kudos-app"
  
  validation {
    condition     = length(var.app_name) > 0 && length(var.app_name) <= 20
    error_message = "App name must be between 1 and 20 characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"  # Free tier eligible
  
  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium",
      "t2.micro", "t2.small", "t2.medium"
    ], var.instance_type)
    error_message = "Instance type must be a valid t3 or t2 instance type."
  }
}

variable "min_servers" {
  description = "Minimum number of web servers"
  type        = number
  default     = 2
  
  validation {
    condition     = var.min_servers >= 1 && var.min_servers <= 10
    error_message = "Minimum servers must be between 1 and 10."
  }
}

variable "max_servers" {
  description = "Maximum number of web servers"
  type        = number
  default     = 4
  
  validation {
    condition     = var.max_servers >= 1 && var.max_servers <= 10
    error_message = "Maximum servers must be between 1 and 10."
  }
}

variable "key_pair_name" {
  description = "Name of AWS key pair for SSH access (create this in AWS console first)"
  type        = string
  default     = ""
  
  # Note: If empty, a new key pair will be created
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed for SSH access (your IP address)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: This allows SSH from anywhere - restrict in production!
}

variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""
}

# ==============================================================================
# LOCAL VALUES - Calculated values used throughout the configuration
# ==============================================================================
locals {
  # Resource naming
  name_prefix = "${var.app_name}-${var.environment}"
  
  # Common tags applied to all resources
  common_tags = {
    Name        = local.name_prefix
    Project     = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "DevOps-Teaching-Ansible"
    CreatedBy   = data.aws_caller_identity.current.arn
    CreatedAt   = timestamp()
  }
  
  # Calculate subnets
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # Port configurations
  app_port     = 3000
  nginx_port   = 80
  ssh_port     = 22
}