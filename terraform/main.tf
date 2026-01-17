# Simple Terraform Configuration for Kudos App on AWS EKS
# This creates a basic EKS cluster to run your React application

# Tell Terraform which tools we need
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS (where we want to deploy)
provider "aws" {
  region = "us-east-1"  # Virginia region
}

# Get information about available zones in our region
data "aws_availability_zones" "available" {
  state = "available"
}