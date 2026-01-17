# PowerShell Script: Create EKS Infrastructure
# This script creates all the AWS infrastructure needed to support your kudos app
# Run this FIRST before deploying your application

Write-Host "🏗️  EKS Infrastructure Creation Workflow" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "This will create:"
Write-Host "- EKS Kubernetes cluster"
Write-Host "- Private network (VPC)"
Write-Host "- Container registry (ECR)"
Write-Host "- Worker nodes (computers to run your app)"
Write-Host ""

# Check prerequisites
Write-Host "🔍 Step 1: Checking prerequisites..." -ForegroundColor Cyan

# Check AWS CLI
if (!(Get-Command "aws" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is required but not installed." -ForegroundColor Red
    Write-Host "   Install from: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

# Check Terraform
if (!(Get-Command "terraform" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Terraform is required but not installed." -ForegroundColor Red
    Write-Host "   Install from: https://www.terraform.io/downloads" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ All tools are installed" -ForegroundColor Green

# Check AWS credentials
Write-Host "🔐 Checking AWS credentials..." -ForegroundColor Cyan
try {
    $awsAccount = aws sts get-caller-identity --query Account --output text 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "AWS credentials not configured"
    }
    $awsRegion = aws configure get region
    if ([string]::IsNullOrEmpty($awsRegion)) { $awsRegion = "us-east-1" }
    
    Write-Host "✅ Connected to AWS Account: $awsAccount in region: $awsRegion" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS credentials not configured" -ForegroundColor Red
    Write-Host "   Run: aws configure" -ForegroundColor Yellow
    exit 1
}

# Prepare Terraform
Write-Host ""
Write-Host "📦 Step 2: Preparing Terraform..." -ForegroundColor Cyan
Set-Location terraform

# Create terraform.tfvars if it doesn't exist
if (!(Test-Path "terraform.tfvars")) {
    Write-Host "📋 Creating terraform.tfvars..." -ForegroundColor Yellow
    Copy-Item "terraform.tfvars.example" "terraform.tfvars"
}

# Initialize Terraform
Write-Host "   Downloading AWS provider..." -ForegroundColor White
terraform init

# Plan the infrastructure
Write-Host ""
Write-Host "📋 Step 3: Planning infrastructure..." -ForegroundColor Cyan
terraform plan -out=infrastructure.tfplan

# Show what will be created
Write-Host ""
Write-Host "📊 Summary of what will be created:" -ForegroundColor Cyan
Write-Host "- 1 EKS cluster (Kubernetes management)"
Write-Host "- 1 VPC with 4 subnets (private network)"
Write-Host "- 2 t3.medium worker nodes (computers)"
Write-Host "- 1 ECR repository (image storage)"
Write-Host "- IAM roles and security groups (permissions)"
Write-Host ""
Write-Host "💰 Estimated cost: ~$150/month while running" -ForegroundColor Yellow
Write-Host "⏱️  Creation time: ~15-20 minutes" -ForegroundColor Yellow
Write-Host ""

# Confirm deployment
$confirmation = Read-Host "🤔 Do you want to create this infrastructure? (y/n)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "👋 Cancelled. Run this script again when ready." -ForegroundColor Yellow
    exit 0
}

# Deploy infrastructure
Write-Host ""
Write-Host "🚀 Step 4: Creating infrastructure..." -ForegroundColor Green
Write-Host "☕ This takes about 15-20 minutes. Perfect time for a coffee break!" -ForegroundColor Yellow
Write-Host ""

terraform apply infrastructure.tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Infrastructure creation failed!" -ForegroundColor Red
    exit 1
}

# Get outputs
Write-Host ""
Write-Host "📊 Step 5: Infrastructure created successfully!" -ForegroundColor Green
Write-Host ""

$clusterName = terraform output -raw cluster_name
$ecrRepoUrl = terraform output -raw ecr_repository_url
$vpcId = terraform output -raw vpc_id

Write-Host "✅ Infrastructure Details:" -ForegroundColor Green
Write-Host "   Cluster Name: $clusterName"
Write-Host "   ECR Repository: $ecrRepoUrl"
Write-Host "   VPC ID: $vpcId"
Write-Host ""

# Configure kubectl
Write-Host "🔧 Step 6: Configuring access to your cluster..." -ForegroundColor Cyan
aws eks --region $awsRegion update-kubeconfig --name $clusterName

Write-Host "   Testing cluster connection..." -ForegroundColor White
kubectl get nodes

Write-Host ""
Write-Host "🎉 Infrastructure Creation Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "✅ What you now have:" -ForegroundColor Green
Write-Host "   - A fully functional Kubernetes cluster"
Write-Host "   - Private container registry"
Write-Host "   - Secure networking"
Write-Host "   - 2 worker nodes ready to run applications"
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Run: .\deploy-app.ps1 (to deploy your kudos app)"
Write-Host "   2. When done, run: .\destroy-infrastructure.ps1 (to save money)"
Write-Host ""
Write-Host "📊 Useful commands:" -ForegroundColor Cyan
Write-Host "   kubectl get nodes                    # See your worker nodes"
Write-Host "   kubectl get namespaces               # See available namespaces"
Write-Host "   aws eks describe-cluster --name $clusterName  # Cluster details"