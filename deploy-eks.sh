#!/bin/bash

# Deployment Script for Kudos App on AWS EKS
# This script automates the complete EKS deployment process

set -e

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
APP_NAME=${APP_NAME:-kudos-app}
ENVIRONMENT=${ENVIRONMENT:-dev}

echo "🚀 Starting EKS deployment of $APP_NAME..."

# Check prerequisites
echo "🔍 Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is required but not installed."
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is required but not installed."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not installed."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is required but not installed."
    exit 1
fi

echo "✅ All prerequisites are installed"

# Step 1: Initialize and apply Terraform
echo "📦 Initializing Terraform..."
cd terraform

if [ ! -f "terraform.tfvars" ]; then
    echo "📋 Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "⚠️  Please review and update terraform.tfvars before continuing"
    read -p "Press Enter to continue after updating terraform.tfvars..."
fi

terraform init

echo "📋 Creating Terraform plan..."
terraform plan -var-file="terraform.tfvars" -out=tfplan

echo "🏗️  Applying Terraform configuration (this may take 15-20 minutes)..."
terraform apply tfplan

# Get outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)

echo "✅ EKS cluster created: $CLUSTER_NAME"
echo "📁 ECR Repository: $ECR_REPO_URL"

# Step 2: Configure kubectl
echo "🔧 Configuring kubectl..."
aws eks --region $AWS_REGION update-kubeconfig --name $CLUSTER_NAME

echo "🔍 Verifying cluster connection..."
kubectl get nodes

# Step 3: Build and push Docker image
echo "🐳 Building Docker image..."
cd ..

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

# Build the image
docker build -t $APP_NAME:latest .

# Tag for ECR
docker tag $APP_NAME:latest $ECR_REPO_URL:latest

# Push to ECR
echo "📤 Pushing image to ECR..."
docker push $ECR_REPO_URL:latest

# Step 4: Wait for Load Balancer Controller and deploy app
echo "⏳ Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

echo "🚀 Deploying application to Kubernetes..."
# The Kubernetes resources are already deployed by Terraform
# Force a rollout to use the new image
kubectl rollout restart deployment/kudos-frontend -n $APP_NAME-$ENVIRONMENT

echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/kudos-frontend -n $APP_NAME-$ENVIRONMENT

# Step 5: Get application URL
echo "🔍 Getting application URL..."
echo "⏳ Waiting for load balancer to be provisioned (this may take a few minutes)..."

# Wait for ingress to get an address
for i in {1..60}; do
    INGRESS_HOST=$(kubectl get ingress kudos-frontend -n $APP_NAME-$ENVIRONMENT -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ ! -z "$INGRESS_HOST" ]; then
        break
    fi
    echo "⏳ Waiting for load balancer... (attempt $i/60)"
    sleep 10
done

if [ ! -z "$INGRESS_HOST" ]; then
    echo "✅ Deployment completed successfully!"
    echo ""
    echo "🌐 Application URL: http://$INGRESS_HOST"
else
    echo "⚠️  Deployment completed but load balancer is still provisioning."
    echo "🔍 Check the AWS Console > EC2 > Load Balancers for the ALB hostname"
    echo "🔍 Or run: kubectl get ingress kudos-frontend -n $APP_NAME-$ENVIRONMENT"
fi

echo ""
echo "📊 Useful commands:"
echo "   View pods: kubectl get pods -n $APP_NAME-$ENVIRONMENT"
echo "   View services: kubectl get services -n $APP_NAME-$ENVIRONMENT"
echo "   View ingress: kubectl get ingress -n $APP_NAME-$ENVIRONMENT"
echo "   View logs: kubectl logs -l app=kudos-frontend -n $APP_NAME-$ENVIRONMENT"
echo ""
echo "🗑️  To cleanup: cd terraform && terraform destroy -var-file=terraform.tfvars"