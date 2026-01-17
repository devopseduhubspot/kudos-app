#!/bin/bash

# Workflow 1: Create EKS Infrastructure
# This script creates all the AWS infrastructure needed to support your kudos app
# Run this FIRST before deploying your application

set -e

echo "🏗️  EKS Infrastructure Creation Workflow"
echo "======================================"
echo "This will create:"
echo "- EKS Kubernetes cluster"
echo "- Private network (VPC)"
echo "- Container registry (ECR)"
echo "- Worker nodes (computers to run your app)"
echo ""

# Check prerequisites
echo "🔍 Step 1: Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is required but not installed."
    echo "   Install from: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is required but not installed."
    echo "   Install from: https://www.terraform.io/downloads"
    exit 1
fi

echo "✅ All tools are installed"

# Check AWS credentials
echo "🔐 Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured"
    echo "   Run: aws configure"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")
echo "✅ Connected to AWS Account: $AWS_ACCOUNT in region: $AWS_REGION"

# Prepare Terraform
echo ""
echo "📦 Step 2: Preparing Terraform..."
cd terraform

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform.tfvars" ]; then
    echo "📋 Creating terraform.tfvars..."
    cp terraform.tfvars.example terraform.tfvars
fi

# Initialize Terraform
echo "   Downloading AWS provider..."
terraform init

# Plan the infrastructure
echo ""
echo "📋 Step 3: Planning infrastructure..."
terraform plan -out=infrastructure.tfplan

# Show what will be created
echo ""
echo "📊 Summary of what will be created:"
echo "- 1 EKS cluster (Kubernetes management)"
echo "- 1 VPC with 4 subnets (private network)"
echo "- 2 t3.medium worker nodes (computers)"
echo "- 1 ECR repository (image storage)"
echo "- IAM roles and security groups (permissions)"
echo ""
echo "💰 Estimated cost: ~$150/month while running"
echo "⏱️  Creation time: ~15-20 minutes"
echo ""

# Confirm deployment
read -p "🤔 Do you want to create this infrastructure? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "👋 Cancelled. Run this script again when ready."
    exit 0
fi

# Deploy infrastructure
echo ""
echo "🚀 Step 4: Creating infrastructure..."
echo "☕ This takes about 15-20 minutes. Perfect time for a coffee break!"
echo ""

terraform apply infrastructure.tfplan

# Get outputs
echo ""
echo "📊 Step 5: Infrastructure created successfully!"
echo ""

CLUSTER_NAME=$(terraform output -raw cluster_name)
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
VPC_ID=$(terraform output -raw vpc_id)

echo "✅ Infrastructure Details:"
echo "   Cluster Name: $CLUSTER_NAME"
echo "   ECR Repository: $ECR_REPO_URL"
echo "   VPC ID: $VPC_ID"
echo ""

# Configure kubectl
echo "🔧 Step 6: Configuring access to your cluster..."
aws eks --region $AWS_REGION update-kubeconfig --name $CLUSTER_NAME

echo "   Testing cluster connection..."
kubectl get nodes

echo ""
echo "🎉 Infrastructure Creation Complete!"
echo ""
echo "✅ What you now have:"
echo "   - A fully functional Kubernetes cluster"
echo "   - Private container registry"
echo "   - Secure networking"
echo "   - 2 worker nodes ready to run applications"
echo ""
echo "📝 Next Steps:"
echo "   1. Run: ./deploy-app.sh (to deploy your kudos app)"
echo "   2. When done, run: ./destroy-infrastructure.sh (to save money)"
echo ""
echo "📊 Useful commands:"
echo "   kubectl get nodes          # See your worker nodes"
echo "   kubectl get namespaces     # See available namespaces"
echo "   aws eks describe-cluster --name $CLUSTER_NAME  # Cluster details"