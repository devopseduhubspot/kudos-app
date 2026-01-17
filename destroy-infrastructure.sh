#!/bin/bash

# Infrastructure Cleanup Workflow
# This script safely destroys all AWS infrastructure
# Use this to avoid ongoing charges when you're done

set -e

echo "🗑️  Infrastructure Cleanup Workflow"
echo "=================================="
echo "This will destroy all AWS resources created for your kudos app:"
echo "- EKS cluster"
echo "- Worker nodes"
echo "- VPC and subnets"
echo "- ECR repository (and all images)"
echo "- IAM roles and security groups"
echo ""

# Warning
echo "⚠️  WARNING: This action cannot be undone!"
echo "💰 This will stop all AWS charges for this project"
echo "📊 Any data in your cluster will be lost"
echo ""

# Check if infrastructure exists
cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo "ℹ️  No infrastructure found to destroy."
    exit 0
fi

# Show what will be destroyed
echo "🔍 Checking current infrastructure..."
terraform refresh

echo ""
echo "📋 Current resources that will be destroyed:"
terraform show | grep "resource" | head -10
echo "   ... and more"
echo ""

# Confirm destruction
read -p "🤔 Are you sure you want to destroy everything? (type 'yes' to confirm): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo "👋 Cancelled. Your infrastructure is safe."
    exit 0
fi

echo ""
echo "🗑️  Destroying infrastructure..."
echo "   This will take 10-15 minutes..."

# First try to delete any running applications
echo "🧹 Step 1: Cleaning up applications..."
if command -v kubectl &> /dev/null; then
    kubectl delete -f ../kudos-deployment.yaml --ignore-not-found=true 2>/dev/null || true
    
    # Wait a bit for load balancers to clean up
    echo "   Waiting for load balancers to clean up..."
    sleep 30
fi

echo "🏗️  Step 2: Destroying AWS infrastructure..."
terraform destroy -auto-approve

# Clean up local files
echo "🧹 Step 3: Cleaning up local files..."
rm -f terraform.tfstate*
rm -f terraform.tfplan*
rm -f infrastructure.tfplan
rm -f ../kudos-deployment.yaml

echo ""
echo "✅ Cleanup Complete!"
echo ""
echo "🎉 All AWS resources have been destroyed"
echo "💰 No more charges will be incurred"
echo "📁 Local Terraform state files cleaned up"
echo ""
echo "🔄 To deploy again in the future:"
echo "   1. Run: ./create-infrastructure.sh"
echo "   2. Run: ./deploy-app.sh"