#!/bin/bash

# =============================================================================
# EBS CSI Driver Setup Script for EKS
# =============================================================================
# This script sets up the AWS EBS CSI driver with proper IRSA configuration
# for EKS clusters to enable persistent volume provisioning.
# 
# Prerequisites:
# - AWS CLI configured
# - kubectl configured for target EKS cluster
# - Appropriate IAM permissions
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Utility functions
print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "============================================================================="
    echo "$1"
    echo "============================================================================="
    echo -e "${NC}"
}

# =============================================================================
# 1. Check Prerequisites
# =============================================================================
print_header "🔍 EBS CSI Driver Setup - Prerequisites Check"

# Check if required tools are installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed or not in PATH"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"  
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    print_status "Please check your kubectl configuration"
    exit 1
fi

# Get cluster info
CLUSTER_NAME=$(kubectl config current-context | cut -d'/' -f2 2>/dev/null || echo "")
if [ -z "$CLUSTER_NAME" ]; then
    print_error "Could not determine cluster name from kubectl context"
    print_status "Please ensure kubectl is configured for your EKS cluster"
    exit 1
fi

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT_ID" ]; then
    print_error "Could not determine AWS account ID"
    print_status "Please check your AWS CLI configuration"
    exit 1
fi

# Get region from kubectl context or AWS CLI
AWS_REGION=$(kubectl config current-context | cut -d'.' -f2 2>/dev/null || aws configure get region || echo "us-east-1")

print_success "Prerequisites check completed"
print_status "Cluster: $CLUSTER_NAME"
print_status "Account ID: $AWS_ACCOUNT_ID"  
print_status "Region: $AWS_REGION"
echo

# =============================================================================
# 2. Setup OIDC Provider
# =============================================================================
print_header "🔧 Setting up OIDC Identity Provider"

# Get OIDC issuer URL
OIDC_ISSUER=$(aws eks describe-cluster --region $AWS_REGION --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text)
OIDC_ID=$(echo $OIDC_ISSUER | cut -d'/' -f5)

print_status "OIDC Issuer: $OIDC_ISSUER"
print_status "OIDC ID: $OIDC_ID"

# Check if OIDC provider exists
OIDC_EXISTS=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?ends_with(Arn, '$OIDC_ID')].Arn" --output text)

if [ -z "$OIDC_EXISTS" ]; then
    print_status "Creating OIDC provider..."
    aws iam create-open-id-connect-provider \
      --url $OIDC_ISSUER \
      --client-id-list sts.amazonaws.com \
      --thumbprint-list 9e99a48a9960b14926bb7f3b02e22da2b0ab7280
    print_success "OIDC provider created"
else
    print_success "OIDC provider already exists: $OIDC_EXISTS"
fi
echo

# =============================================================================
# 3. Create IAM Role for EBS CSI Driver
# =============================================================================
print_header "🔐 Setting up IAM Role for EBS CSI Driver"

# Check if IAM role exists
ROLE_EXISTS=$(aws iam get-role --role-name AmazonEKS_EBS_CSI_DriverRole --query 'Role.RoleName' --output text 2>/dev/null || echo "")

if [ "$ROLE_EXISTS" != "AmazonEKS_EBS_CSI_DriverRole" ]; then
    print_status "Creating EBS CSI IAM role..."
    
    # Create trust policy
    cat > /tmp/ebs-csi-trust-policy.json << EOF
{
  "Version": "2012-10-17", 
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/${OIDC_ISSUER#https://}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_ISSUER#https://}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa",
          "${OIDC_ISSUER#https://}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
    
    # Create role and attach policy
    aws iam create-role --role-name AmazonEKS_EBS_CSI_DriverRole --assume-role-policy-document file:///tmp/ebs-csi-trust-policy.json
    aws iam attach-role-policy --role-name AmazonEKS_EBS_CSI_DriverRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
    
    # Clean up temp file
    rm -f /tmp/ebs-csi-trust-policy.json
    
    print_success "EBS CSI IAM role created and policy attached"
else
    print_success "EBS CSI IAM role already exists"
fi
echo

# =============================================================================
# 4. Install EBS CSI Driver Addon
# =============================================================================
print_header "📦 Installing EBS CSI Driver Addon"

# Check if EBS CSI addon exists
ADDON_STATUS=$(aws eks describe-addon --cluster-name $CLUSTER_NAME --addon-name aws-ebs-csi-driver --region $AWS_REGION --query 'addon.status' --output text 2>/dev/null || echo "NOT_FOUND")

print_status "Current addon status: $ADDON_STATUS"

if [ "$ADDON_STATUS" != "ACTIVE" ]; then
    # Delete addon if it exists in failed state
    if [ "$ADDON_STATUS" != "NOT_FOUND" ]; then
        print_status "Removing existing addon in $ADDON_STATUS state..."
        aws eks delete-addon --cluster-name $CLUSTER_NAME --addon-name aws-ebs-csi-driver --region $AWS_REGION
        print_status "Waiting for addon deletion..."
        aws eks wait addon-deleted --cluster-name $CLUSTER_NAME --addon-name aws-ebs-csi-driver --region $AWS_REGION
    fi
    
    print_status "Installing EBS CSI driver addon..."
    aws eks create-addon \
      --cluster-name $CLUSTER_NAME \
      --addon-name aws-ebs-csi-driver \
      --service-account-role-arn arn:aws:iam::$AWS_ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole \
      --region $AWS_REGION
    
    print_status "Waiting for EBS CSI driver to be active (this may take a few minutes)..."
    timeout 600 aws eks wait addon-active --cluster-name $CLUSTER_NAME --addon-name aws-ebs-csi-driver --region $AWS_REGION
    print_success "EBS CSI driver installed and active"
else
    print_success "EBS CSI driver already active"
fi
echo

# =============================================================================
# 5. Verify Installation
# =============================================================================
print_header "✅ Verifying EBS CSI Driver Installation"

# Check addon status
FINAL_STATUS=$(aws eks describe-addon --cluster-name $CLUSTER_NAME --addon-name aws-ebs-csi-driver --region $AWS_REGION --query 'addon.status' --output text)
print_status "EBS CSI Addon Status: $FINAL_STATUS"

# Check controller pods
print_status "Checking EBS CSI controller pods..."
kubectl get pods -n kube-system -l app=ebs-csi-controller

# Check node pods  
print_status "Checking EBS CSI node pods..."
kubectl get pods -n kube-system -l app=ebs-csi-node

# Check storage class
print_status "Checking storage classes..."
kubectl get storageclass

# Check if gp2 storage class exists
if kubectl get storageclass gp2 &> /dev/null; then
    print_success "gp2 storage class is available"
else
    print_warning "gp2 storage class not found"
fi

echo
print_header "🎉 EBS CSI Driver Setup Complete!"
print_success "Your cluster is now ready for persistent volume provisioning"
print_status "You can now deploy applications that require persistent storage"
echo