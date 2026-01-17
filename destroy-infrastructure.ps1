# PowerShell Script: Infrastructure Cleanup
# This script safely destroys all AWS infrastructure
# Use this to avoid ongoing charges when you're done

Write-Host "🗑️  Infrastructure Cleanup Workflow" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor Yellow
Write-Host "This will destroy all AWS resources created for your kudos app:"
Write-Host "- EKS cluster"
Write-Host "- Worker nodes"
Write-Host "- VPC and subnets"
Write-Host "- ECR repository (and all images)"
Write-Host "- IAM roles and security groups"
Write-Host ""

# Warning
Write-Host "⚠️  WARNING: This action cannot be undone!" -ForegroundColor Red
Write-Host "💰 This will stop all AWS charges for this project" -ForegroundColor Green
Write-Host "📊 Any data in your cluster will be lost" -ForegroundColor Red
Write-Host ""

# Check if infrastructure exists
Set-Location terraform

if (!(Test-Path "terraform.tfstate")) {
    Write-Host "ℹ️  No infrastructure found to destroy." -ForegroundColor Cyan
    exit 0
}

# Show what will be destroyed
Write-Host "🔍 Checking current infrastructure..." -ForegroundColor Cyan
terraform refresh

Write-Host ""
Write-Host "📋 Current resources that will be destroyed:" -ForegroundColor Yellow
$resources = terraform show | Select-String "resource" | Select-Object -First 10
$resources | ForEach-Object { Write-Host "   $_" }
Write-Host "   ... and more"
Write-Host ""

# Confirm destruction
$confirmation = Read-Host "🤔 Are you sure you want to destroy everything? (type 'yes' to confirm)"

if ($confirmation -ne "yes") {
    Write-Host "👋 Cancelled. Your infrastructure is safe." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "🗑️  Destroying infrastructure..." -ForegroundColor Yellow
Write-Host "   This will take 10-15 minutes..." -ForegroundColor Yellow

# First try to delete any running applications
Write-Host "🧹 Step 1: Cleaning up applications..." -ForegroundColor Cyan
if (Get-Command "kubectl" -ErrorAction SilentlyContinue) {
    kubectl delete -f ..\kudos-deployment.yaml --ignore-not-found=true 2>$null
    
    # Wait a bit for load balancers to clean up
    Write-Host "   Waiting for load balancers to clean up..." -ForegroundColor White
    Start-Sleep -Seconds 30
}

Write-Host "🏗️  Step 2: Destroying AWS infrastructure..." -ForegroundColor Cyan
terraform destroy -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Some resources may not have been destroyed!" -ForegroundColor Red
    Write-Host "   Check the AWS Console and manually delete remaining resources" -ForegroundColor Yellow
}

# Clean up local files
Write-Host "🧹 Step 3: Cleaning up local files..." -ForegroundColor Cyan
Remove-Item -Path "terraform.tfstate*" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "terraform.tfplan*" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "infrastructure.tfplan" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "..\kudos-deployment.yaml" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "✅ Cleanup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🎉 All AWS resources have been destroyed" -ForegroundColor Green
Write-Host "💰 No more charges will be incurred" -ForegroundColor Green
Write-Host "📁 Local Terraform state files cleaned up" -ForegroundColor Green
Write-Host ""
Write-Host "🔄 To deploy again in the future:" -ForegroundColor Cyan
Write-Host "   1. Run: .\create-infrastructure.ps1"
Write-Host "   2. Run: .\deploy-app.ps1"