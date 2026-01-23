# GitHub Actions Prerequisites Setup Script for Windows
# This script sets up all AWS resources needed for the GitHub Actions workflows
#
# =============================================================================
# USAGE EXAMPLES
# =============================================================================
# Setup Mode:
#   .\Setup-GitHubActions-Clean.ps1
#   .\Setup-GitHubActions-Clean.ps1 -ProjectName "my-app" -Environment "dev"
#   .\Setup-GitHubActions-Clean.ps1 -ProjectName "my-app" -Environment "prod" -AWSRegion "us-west-2"
#
# Cleanup Mode (DESTRUCTIVE):
#   .\Setup-GitHubActions-Clean.ps1 -Cleanup
#   .\Setup-GitHubActions-Clean.ps1 -Cleanup -Environment "staging" -SkipConfirmation
# =============================================================================

param(
    [string]$ProjectName = "kudos-app",
    [string]$AWSRegion = "us-east-1",
    [string]$Environment = "dev",
    [switch]$SkipConfirmation,
    [switch]$Cleanup
)

# Function to check AWS CLI setup
function Test-AWSSetup {
    try {
        $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
        Write-Host "AWS CLI configured for account: $($identity.Account)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "AWS CLI not configured. Run 'aws configure' first." -ForegroundColor Red
        return $false
    }
}

# Function to create S3 bucket
function New-S3Bucket {
    param([string]$BucketName)
    
    Write-Host "Creating S3 bucket: $BucketName..." -ForegroundColor Yellow
    
    # Check if bucket exists
    aws s3 ls "s3://$BucketName" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Bucket already exists: $BucketName" -ForegroundColor Green
        return $BucketName
    }
    
    # Create bucket - capture output but return clean bucket name
    $output = aws s3 mb "s3://$BucketName" --region $AWSRegion 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create S3 bucket" -ForegroundColor Red
        Write-Host "Error: $output" -ForegroundColor Red
        return $null
    }
    
    Write-Host "S3 bucket creation output: $output" -ForegroundColor Gray
    
    # Enable versioning
    aws s3api put-bucket-versioning --bucket $BucketName --versioning-configuration Status=Enabled
    
    # Enable encryption
    $encryptConfig = '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    $encryptConfig | Out-File -FilePath "temp-encrypt.json" -Encoding ASCII
    aws s3api put-bucket-encryption --bucket $BucketName --server-side-encryption-configuration file://temp-encrypt.json
    Remove-Item "temp-encrypt.json" -Force
    
    Write-Host "S3 bucket created successfully: $BucketName" -ForegroundColor Green
    # Return ONLY the bucket name, not the AWS CLI output
    return $BucketName
}

# Function to create DynamoDB table
function New-DynamoDBTable {
    param([string]$TableName)
    
    Write-Host "Creating DynamoDB table: $TableName..." -ForegroundColor Yellow
    
    # Check if table exists
    aws dynamodb describe-table --table-name $TableName --region $AWSRegion 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "DynamoDB table already exists: $TableName" -ForegroundColor Green
        return $true
    }
    
    # Create table
    aws dynamodb create-table --table-name $TableName --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 --region $AWSRegion
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create DynamoDB table" -ForegroundColor Red
        return $false
    }
    
    # Wait for table to be active
    Write-Host "Waiting for DynamoDB table to be active..." -ForegroundColor Yellow
    do {
        Start-Sleep -Seconds 5
        $status = aws dynamodb describe-table --table-name $TableName --query 'Table.TableStatus' --output text 2>$null
    } while ($status -ne "ACTIVE" -and $status -ne $null)
    
    Write-Host "DynamoDB table created successfully: $TableName" -ForegroundColor Green
    return $true
}

# ECR Repository Management is now handled by Terraform
# ECR repositories are automatically created when running terraform apply
# and destroyed when running terraform destroy

# Function to update Terraform backend
function Update-Backend {
    param([string]$BucketName)
    
    $backendFile = Join-Path $PSScriptRoot "terraform\backend.tf"
    
    if (Test-Path $backendFile) {
        $content = Get-Content $backendFile -Raw
        $content = $content -replace 'bucket = ".*"', "bucket = `"$BucketName`""
        $content | Out-File -FilePath $backendFile -Encoding UTF8
        Write-Host "Backend configuration updated" -ForegroundColor Green
    } else {
        Write-Host "Backend file not found: $backendFile" -ForegroundColor Yellow
    }
}

# Function to delete S3 bucket
function Remove-S3Bucket {
    param([string]$BucketName)
    
    Write-Host "Deleting S3 bucket: $BucketName..." -ForegroundColor Yellow
    
    # Check if bucket exists
    aws s3 ls "s3://$BucketName" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Bucket does not exist: $BucketName" -ForegroundColor Yellow
        return $true
    }
    
    # Delete all object versions and delete markers for versioned buckets
    Write-Host "Checking for versioned objects..." -ForegroundColor Cyan
    $versionsJson = aws s3api list-object-versions --bucket $BucketName --output json 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $versionsJson) {
        $versions = $versionsJson | ConvertFrom-Json
        
        # Delete all versions
        if ($versions.Versions) {
            foreach ($version in $versions.Versions) {
                Write-Host "Deleting version: $($version.Key) (Version: $($version.VersionId))" -ForegroundColor Gray
                aws s3api delete-object --bucket $BucketName --key $version.Key --version-id $version.VersionId 2>$null
            }
        }
        
        # Delete all delete markers
        if ($versions.DeleteMarkers) {
            foreach ($deleteMarker in $versions.DeleteMarkers) {
                Write-Host "Deleting marker: $($deleteMarker.Key) (Version: $($deleteMarker.VersionId))" -ForegroundColor Gray
                aws s3api delete-object --bucket $BucketName --key $deleteMarker.Key --version-id $deleteMarker.VersionId 2>$null
            }
        }
    }
    
    # Also try standard object removal for non-versioned objects
    aws s3 rm "s3://$BucketName" --recursive 2>$null
    
    # Delete bucket
    aws s3 rb "s3://$BucketName"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "S3 bucket deleted: $BucketName" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Failed to delete S3 bucket: $BucketName" -ForegroundColor Red
        return $false
    }
}

# Function to delete DynamoDB table
function Remove-DynamoDBTable {
    param([string]$TableName)
    
    Write-Host "Deleting DynamoDB table: $TableName..." -ForegroundColor Yellow
    
    # Check if table exists
    aws dynamodb describe-table --table-name $TableName --region $AWSRegion 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "DynamoDB table does not exist: $TableName" -ForegroundColor Yellow
        return $true
    }
    
    # Delete table
    aws dynamodb delete-table --table-name $TableName --region $AWSRegion
    if ($LASTEXITCODE -eq 0) {
        Write-Host "DynamoDB table deleted: $TableName" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Failed to delete DynamoDB table: $TableName" -ForegroundColor Red
        return $false
    }
}

# ECR Repository Management is now handled by Terraform
# ECR repositories are automatically destroyed when running terraform destroy

# Main setup function
function Invoke-Setup {
    Write-Host "GitHub Actions Prerequisites Setup" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    
    if (-not (Test-AWSSetup)) {
        return
    }
    
    # Generate unique bucket name
    $bucketName = "terraform-state-$ProjectName-$(Get-Random)"
    $tableName = "terraform-locks"
    
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  Project: $ProjectName" -ForegroundColor White
    Write-Host "  Environment: $Environment" -ForegroundColor White
    Write-Host "  Region: $AWSRegion" -ForegroundColor White
    Write-Host "  S3 Bucket: $bucketName" -ForegroundColor White
    Write-Host "  DynamoDB Table: $tableName" -ForegroundColor White
    Write-Host "  ECR Repositories: Managed by Terraform" -ForegroundColor Gray
    Write-Host ""
    
    if (-not $SkipConfirmation) {
        $confirm = Read-Host "Continue with setup? (y/n)"
        if ($confirm -ne "y") {
            Write-Host "Setup cancelled" -ForegroundColor Red
            return
        }
    }
    
    # Create resources
    $bucket = New-S3Bucket -BucketName $bucketName
    if (-not $bucket) { return }
    
    $dynamoSuccess = New-DynamoDBTable -TableName $tableName
    if (-not $dynamoSuccess) { return }
    
    # ECR repositories will be created automatically by Terraform
    
    # Update backend
    Update-Backend -BucketName $bucket
    
    Write-Host ""
    Write-Host "Setup completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "GitHub Repository Secrets:" -ForegroundColor Cyan
    Write-Host "  AWS_ACCESS_KEY_ID = [Your AWS Access Key]" -ForegroundColor White
    Write-Host "  AWS_SECRET_ACCESS_KEY = [Your AWS Secret Key]" -ForegroundColor White
    Write-Host "  TERRAFORM_STATE_BUCKET = $bucket" -ForegroundColor White
    Write-Host "" 
    
    Write-Host "💡 ECR Repositories will be created by Terraform:" -ForegroundColor Cyan
    Write-Host "   Run 'terraform apply' to create ECR repositories automatically" -ForegroundColor White
    Write-Host "   (No manual ECR setup needed)" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Add the above secrets to your GitHub repository" -ForegroundColor White
    Write-Host "  2. Run 'terraform init' in the terraform directory" -ForegroundColor White
    Write-Host "  3. Run 'terraform apply' to create all infrastructure (including ECR)" -ForegroundColor White
    Write-Host "  4. Test your GitHub Actions workflows" -ForegroundColor White
}

# Main cleanup function
function Invoke-Cleanup {
    Write-Host "GitHub Actions Cleanup" -ForegroundColor Red
    Write-Host "======================" -ForegroundColor Red
    Write-Host ""
    Write-Host "WARNING: This will delete ALL resources!" -ForegroundColor Red
    
    if (-not (Test-AWSSetup)) {
        return
    }
    
    if (-not $SkipConfirmation) {
        Write-Host ""
        Write-Host "Resources to be deleted:" -ForegroundColor Yellow
        Write-Host "  - All S3 buckets matching: terraform-state-$ProjectName-*" -ForegroundColor White
        Write-Host "  - DynamoDB table: terraform-locks" -ForegroundColor White
        Write-Host "  - ECR repositories: Use 'terraform destroy' to delete" -ForegroundColor Gray
        Write-Host ""
        $confirm = Read-Host "Type 'DELETE' to confirm"
        if ($confirm -ne "DELETE") {
            Write-Host "Cleanup cancelled" -ForegroundColor Red
            return
        }
    }
    
    # ECR repositories will be deleted by Terraform destroy
    Write-Host "ECR repositories will be deleted by 'terraform destroy'" -ForegroundColor Cyan
    
    # Find and delete S3 buckets
    Write-Host "Finding S3 buckets to delete..." -ForegroundColor Yellow
    $allBuckets = aws s3 ls | ForEach-Object { ($_ -split '\s+')[-1] }
    $matchingBuckets = $allBuckets | Where-Object { $_ -like "terraform-state-$ProjectName-*" }
    
    if ($matchingBuckets) {
        foreach ($bucket in $matchingBuckets) {
            Remove-S3Bucket -BucketName $bucket
        }
    } else {
        Write-Host "No matching S3 buckets found" -ForegroundColor Yellow
    }
    
    # Delete DynamoDB table
    Remove-DynamoDBTable -TableName "terraform-locks"
    
    Write-Host ""
    Write-Host "Cleanup completed!" -ForegroundColor Green
    Write-Host "All AWS resources have been deleted." -ForegroundColor Green
}

# Main execution
if ($Cleanup) {
    Invoke-Cleanup
} else {
    Invoke-Setup
}