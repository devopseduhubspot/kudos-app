# ==============================================================================
# TERRAFORM CONFIGURATION FOR EC2 DEPLOYMENT
# ==============================================================================
# This file creates AWS infrastructure for traditional server-based deployment
# Perfect for teaching DevOps concepts with Ansible configuration management
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Optional: Uncomment for remote state management
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "ec2-deployment/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# ==============================================================================
# PROVIDER CONFIGURATION
# ==============================================================================
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.app_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Purpose     = "DevOps-Teaching-Ansible"
    }
  }
}

# ==============================================================================
# DATA SOURCES - Get existing AWS resources
# ==============================================================================
# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get current AWS caller identity
data "aws_caller_identity" "current" {}