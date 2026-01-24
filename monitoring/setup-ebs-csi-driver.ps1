# =============================================================================
# EBS CSI Driver Setup Script for EKS (PowerShell)
# =============================================================================
# This script sets up the AWS EBS CSI driver with proper IRSA configuration
# for EKS clusters to enable persistent volume provisioning.
# 
# Prerequisites:
# - AWS CLI configured
# - kubectl configured for target EKS cluster  
# - Appropriate IAM permissions
# =============================================================================

param(
    [string]$ClusterName = "",
    [string]$Region = "us-east-1"
)

# Set error handling
$ErrorActionPreference = "Stop"

# Utility functions
function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "❌ ERROR: $Message" -ForegroundColor Red
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠️  WARNING: $Message" -ForegroundColor Yellow
}

function Write-Status {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n=============================================================================" -ForegroundColor Blue
    Write-Host "$Message" -ForegroundColor Blue
    Write-Host "=============================================================================" -ForegroundColor Blue
}

# =============================================================================
# 1. Check Prerequisites
# =============================================================================
Write-Header "🔍 EBS CSI Driver Setup - Prerequisites Check"

# Check if required tools are installed
try {
    aws --version | Out-Null
    Write-Success "AWS CLI is available"
} catch {
    Write-Error-Custom "AWS CLI is not installed or not in PATH"
    exit 1
}

try {
    kubectl version --client | Out-Null
    Write-Success "kubectl is available"
} catch {
    Write-Error-Custom "kubectl is not installed or not in PATH"
    exit 1
}

# Check if we can connect to cluster
try {
    kubectl cluster-info | Out-Null
    Write-Success "Connected to Kubernetes cluster"
} catch {
    Write-Error-Custom "Cannot connect to Kubernetes cluster"
    Write-Status "Please check your kubectl configuration"
    exit 1
}

# Get cluster info
if ([string]::IsNullOrEmpty($ClusterName)) {
    try {
        $context = kubectl config current-context
        $ClusterName = ($context -split '/')[1]
        if ([string]::IsNullOrEmpty($ClusterName)) {
            throw "Could not extract cluster name from context"
        }
    } catch {
        Write-Error-Custom "Could not determine cluster name from kubectl context"
        Write-Status "Please provide cluster name using -ClusterName parameter"
        exit 1
    }
}

# Get AWS account ID
try {
    $AwsAccountId = aws sts get-caller-identity --query Account --output text
    if ([string]::IsNullOrEmpty($AwsAccountId)) {
        throw "Empty account ID returned"
    }
} catch {
    Write-Error-Custom "Could not determine AWS account ID"
    Write-Status "Please check your AWS CLI configuration"
    exit 1
}

Write-Success "Prerequisites check completed"
Write-Status "Cluster: $ClusterName"
Write-Status "Account ID: $AwsAccountId"
Write-Status "Region: $Region"

# =============================================================================
# 2. Setup OIDC Provider
# =============================================================================
Write-Header "🔧 Setting up OIDC Identity Provider"

# Get OIDC issuer URL
try {
    $OidcIssuer = aws eks describe-cluster --region $Region --name $ClusterName --query "cluster.identity.oidc.issuer" --output text
    $OidcId = ($OidcIssuer -split '/')[-1]
    
    Write-Status "OIDC Issuer: $OidcIssuer"
    Write-Status "OIDC ID: $OidcId"
} catch {
    Write-Error-Custom "Could not get OIDC issuer for cluster $ClusterName"
    exit 1
}

# Check if OIDC provider exists
try {
    $OidcExists = aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?ends_with(Arn, '$OidcId')].Arn" --output text
    
    if ([string]::IsNullOrEmpty($OidcExists)) {
        Write-Status "Creating OIDC provider..."
        aws iam create-open-id-connect-provider --url $OidcIssuer --client-id-list sts.amazonaws.com --thumbprint-list 9e99a48a9960b14926bb7f3b02e22da2b0ab7280
        Write-Success "OIDC provider created"
    } else {
        Write-Success "OIDC provider already exists: $OidcExists"
    }
} catch {
    Write-Error-Custom "Failed to create OIDC provider: $_"
    exit 1
}

# =============================================================================
# 3. Create IAM Role for EBS CSI Driver
# =============================================================================
Write-Header "🔐 Setting up IAM Role for EBS CSI Driver"

$RoleName = "AmazonEKS_EBS_CSI_DriverRole"

# Check if IAM role exists
try {
    $RoleExists = aws iam get-role --role-name $RoleName --query 'Role.RoleName' --output text 2>$null
    if ($LASTEXITCODE -ne 0) { $RoleExists = "" }
} catch {
    $RoleExists = ""
}

if ($RoleExists -ne $RoleName) {
    Write-Status "Creating EBS CSI IAM role..."
    
    # Create trust policy
    $TrustPolicy = @{
        "Version" = "2012-10-17"
        "Statement" = @(
            @{
                "Effect" = "Allow"
                "Principal" = @{
                    "Federated" = "arn:aws:iam::${AwsAccountId}:oidc-provider/$($OidcIssuer.Replace('https://', ''))"
                }
                "Action" = "sts:AssumeRoleWithWebIdentity"
                "Condition" = @{
                    "StringEquals" = @{
                        "$($OidcIssuer.Replace('https://', '')):sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
                        "$($OidcIssuer.Replace('https://', '')):aud" = "sts.amazonaws.com"
                    }
                }
            }
        )
    } | ConvertTo-Json -Depth 10
    
    # Save to temp file
    $TempFile = [System.IO.Path]::GetTempFileName()
    $TrustPolicy | Out-File -FilePath $TempFile -Encoding UTF8
    
    try {
        # Create role and attach policy
        aws iam create-role --role-name $RoleName --assume-role-policy-document "file://$TempFile"
        aws iam attach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        
        Write-Success "EBS CSI IAM role created and policy attached"
    } finally {
        # Clean up temp file
        Remove-Item $TempFile -ErrorAction SilentlyContinue
    }
} else {
    Write-Success "EBS CSI IAM role already exists"
}

# =============================================================================
# 4. Install EBS CSI Driver Addon
# =============================================================================
Write-Header "📦 Installing EBS CSI Driver Addon"

# Check if EBS CSI addon exists
try {
    $AddonStatus = aws eks describe-addon --cluster-name $ClusterName --addon-name aws-ebs-csi-driver --region $Region --query 'addon.status' --output text 2>$null
    if ($LASTEXITCODE -ne 0) { $AddonStatus = "NOT_FOUND" }
} catch {
    $AddonStatus = "NOT_FOUND"
}

Write-Status "Current addon status: $AddonStatus"

if ($AddonStatus -ne "ACTIVE") {
    # Delete addon if it exists in failed state
    if ($AddonStatus -ne "NOT_FOUND") {
        Write-Status "Removing existing addon in $AddonStatus state..."
        aws eks delete-addon --cluster-name $ClusterName --addon-name aws-ebs-csi-driver --region $Region
        Write-Status "Waiting for addon deletion..."
        aws eks wait addon-deleted --cluster-name $ClusterName --addon-name aws-ebs-csi-driver --region $Region
    }
    
    Write-Status "Installing EBS CSI driver addon..."
    aws eks create-addon --cluster-name $ClusterName --addon-name aws-ebs-csi-driver --service-account-role-arn "arn:aws:iam::${AwsAccountId}:role/$RoleName" --region $Region
    
    Write-Status "Waiting for EBS CSI driver to be active (this may take a few minutes)..."
    aws eks wait addon-active --cluster-name $ClusterName --addon-name aws-ebs-csi-driver --region $Region
    Write-Success "EBS CSI driver installed and active"
} else {
    Write-Success "EBS CSI driver already active"
}

# =============================================================================
# 5. Verify Installation
# =============================================================================
Write-Header "✅ Verifying EBS CSI Driver Installation"

# Check addon status
$FinalStatus = aws eks describe-addon --cluster-name $ClusterName --addon-name aws-ebs-csi-driver --region $Region --query 'addon.status' --output text
Write-Status "EBS CSI Addon Status: $FinalStatus"

# Check controller pods
Write-Status "Checking EBS CSI controller pods..."
kubectl get pods -n kube-system -l app=ebs-csi-controller

# Check node pods
Write-Status "Checking EBS CSI node pods..."  
kubectl get pods -n kube-system -l app=ebs-csi-node

# Check storage class
Write-Status "Checking storage classes..."
kubectl get storageclass

# Check if gp2 storage class exists
try {
    kubectl get storageclass gp2 | Out-Null
    Write-Success "gp2 storage class is available"
} catch {
    Write-Warning-Custom "gp2 storage class not found"
}

Write-Header "🎉 EBS CSI Driver Setup Complete!"
Write-Success "Your cluster is now ready for persistent volume provisioning"
Write-Status "You can now deploy applications that require persistent storage"