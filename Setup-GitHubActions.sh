#!/bin/bash

# GitHub Actions Prerequisites Setup Script for WSL/Linux
# This script sets up all AWS resources needed for the GitHub Actions workflows
#
# =============================================================================
# WHAT THIS SCRIPT DOES
# =============================================================================
# Creates AWS infrastructure for GitHub Actions CI/CD:
# - S3 bucket for Terraform state storage (with encryption & versioning)
# - DynamoDB table for state locking (prevents concurrent modifications)
# - Updates your Terraform backend configuration automatically
# - Provides GitHub repository secrets for authentication
#
# =============================================================================
# PREREQUISITES
# =============================================================================
# 1. AWS Account with administrator permissions
# 2. AWS CLI installed and configured: aws configure
#    - Ubuntu/Debian: sudo apt install awscli
#    - Or: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
# 3. Bash shell (WSL, Linux, macOS)
# 4. This script in your project root directory
#
# =============================================================================
# USAGE EXAMPLES
# =============================================================================
# 
# Setup Mode (Creates Resources):
# ./Setup-GitHubActions.sh setup                                    # Basic setup (dev environment)
# ./Setup-GitHubActions.sh setup my-app                             # Custom project (dev environment)  
# ./Setup-GitHubActions.sh setup my-app us-west-2 staging           # Custom project, region, and environment
# ./Setup-GitHubActions.sh setup my-app us-west-2 prod true         # Production setup, skip confirmations
# 
# Cleanup Mode (Deletes Everything - DESTRUCTIVE):
# ./Setup-GitHubActions.sh cleanup                                  # Delete all resources
# ./Setup-GitHubActions.sh cleanup my-app                           # Custom project cleanup
# ./Setup-GitHubActions.sh cleanup my-app us-west-2 staging         # Environment-specific cleanup
# PROJECT_NAME=my-app ENVIRONMENT=prod SKIP_CONFIRMATION=true ./Setup-GitHubActions.sh cleanup # Cleanup without prompts
#
# =============================================================================
# WHAT GETS CREATED
# =============================================================================
# AWS Resources:
# - S3 Bucket: terraform-state-{ProjectName}-{RandomNumber}
#   * AES256 encryption enabled
#   * Versioning enabled
#   * Stores Terraform state files securely
# 
# - DynamoDB Table: terraform-locks
#   * Primary Key: LockID (String)
#   * Provisioned throughput: 1 read, 1 write unit
#   * Prevents concurrent Terraform operations
#
# =============================================================================
# ESTIMATED COSTS
# =============================================================================
# These resources cost approximately $1-3 per month:
# - S3 bucket: ~$0.50/month (for state files)
# - DynamoDB table: ~$1.50/month (1 RCU + 1 WCU)
# 
# NOTE: Your EKS infrastructure will cost ~$108/month:
# - EKS Cluster: $73/month (control plane)
# - 2x t3.small nodes: ~$30/month
# - LoadBalancer: ~$18/month
# 
# IMPORTANT: Use --cleanup when done with demos!
#
# =============================================================================
# GITHUB REPOSITORY SETUP
# =============================================================================
# After running this script, add these secrets to your GitHub repository:
# GitHub.com → Your Repo → Settings → Secrets and variables → Actions
# 
# Required Secrets:
# - AWS_ACCESS_KEY_ID: Your AWS access key
# - AWS_SECRET_ACCESS_KEY: Your AWS secret key  
# - TERRAFORM_STATE_BUCKET: The S3 bucket name (script will show you this)
# - ECR_REGISTRY: Your ECR registry URL (e.g., 036983629554.dkr.ecr.us-east-1.amazonaws.com)
# - SNYK_TOKEN: Snyk API token for security scanning
#
# =============================================================================
# WORKFLOW PROCESS
# =============================================================================
# 1. Run this setup script (creates S3 + DynamoDB)
# 2. Add GitHub secrets (authentication for workflows)
# 3. Run: terraform init (initializes remote state)
# 4. Use GitHub Actions workflows:
#    - Infrastructure workflow: Creates EKS cluster
#    - Docker workflow: Builds and deploys your app
# 5. When done: Use --cleanup to delete everything
#
# =============================================================================
# TROUBLESHOOTING
# =============================================================================
# "AWS CLI is not installed":
#   → Ubuntu/Debian: sudo apt install awscli
#   → Or follow: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
# 
# "AWS CLI not configured":
#   → Run: aws configure
#   → Enter your AWS Access Key ID and Secret
# 
# "Access Denied" errors:
#   → Your AWS user needs Administrator permissions
#   → Or specific permissions for S3, DynamoDB, IAM
# 
# "Permission denied" when running script:
#   → Run: chmod +x Setup-GitHubActions.sh
#   → Then: ./Setup-GitHubActions.sh
# 
# "terraform init fails":
#   → Make sure S3 bucket was created successfully
#   → Check AWS credentials are still valid
#
# =============================================================================

set -e  # Exit on any error

# Parse command line arguments
MODE="$1"
PROJECT_NAME="${2:-kudos-app}"
AWS_REGION="${3:-us-east-1}"
ENVIRONMENT="${4:-dev}"
SKIP_CONFIRMATION="${5:-false}"

# Allow environment variables to override defaults
PROJECT_NAME="${PROJECT_NAME:-$PROJECT_NAME}"
AWS_REGION="${AWS_REGION:-$AWS_REGION}"
ENVIRONMENT="${ENVIRONMENT:-$ENVIRONMENT}"
SKIP_CONFIRMATION="${SKIP_CONFIRMATION:-$SKIP_CONFIRMATION}"

echo "🚀 GitHub Actions Prerequisites Setup for $PROJECT_NAME-$ENVIRONMENT"
echo "================================================================="

# Function to check if AWS CLI is installed and configured
check_aws_setup() {
    echo "🔍 Checking AWS CLI setup..."
    
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI is not installed. Please install it first."
        echo "   Ubuntu/Debian: sudo apt install awscli"
        echo "   Or: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html"
        return 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "❌ AWS CLI not configured. Please run 'aws configure' first."
        return 1
    fi
    
    local aws_account=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
    echo "✅ AWS CLI configured for account: $aws_account"
    return 0
}

# Function to create S3 bucket
create_terraform_state_bucket() {
    local bucket_name="$1"
    
    echo "🪣 Creating S3 bucket for Terraform state..."
    
    # Check if bucket already exists
    if aws s3 ls "s3://$bucket_name" &> /dev/null; then
        echo "✅ Bucket $bucket_name already exists"
        echo "$bucket_name"
        return 0
    fi
    
    # Create bucket
    if ! aws s3 mb "s3://$bucket_name" --region "$AWS_REGION"; then
        echo "❌ Failed to create S3 bucket"
        return 1
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$bucket_name" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    local encryption_config=$(cat <<EOF
{
  "Rules": [
    {
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }
  ]
}
EOF
)
    
    echo "$encryption_config" > temp-encryption.json
    aws s3api put-bucket-encryption \
        --bucket "$bucket_name" \
        --server-side-encryption-configuration file://temp-encryption.json
    rm -f temp-encryption.json
    
    echo "✅ S3 bucket created and configured: $bucket_name"
    echo "$bucket_name"
}

# Function to create DynamoDB table
create_dynamodb_lock_table() {
    local table_name="$1"
    
    echo "🗄️ Creating DynamoDB table for state locking..."
    
    # Check if table already exists
    if aws dynamodb describe-table --table-name "$table_name" &> /dev/null; then
        echo "✅ DynamoDB table $table_name already exists"
        return 0
    fi
    
    # Create table
    if ! aws dynamodb create-table \
        --table-name "$table_name" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
        --region "$AWS_REGION" &> /dev/null; then
        echo "❌ Failed to create DynamoDB table"
        return 1
    fi
    
    # Wait for table to be active
    echo "⏳ Waiting for DynamoDB table to be active..."
    while true; do
        local table_status=$(aws dynamodb describe-table \
            --table-name "$table_name" \
            --query 'Table.TableStatus' \
            --output text 2>/dev/null)
        
        if [ "$table_status" = "ACTIVE" ]; then
            break
        fi
        
        if [ "$table_status" = "None" ] || [ -z "$table_status" ]; then
            echo "❌ Failed to get table status"
            return 1
        fi
        
        sleep 5
    done
    
    echo "✅ DynamoDB table created: $table_name"
    return 0
}

# Function to create ECR repository
create_ecr_repository() {
    local repo_name="$1"
    
    echo "📦 Creating ECR repository..."
    
    # Check if repository already exists
    if aws ecr describe-repositories --repository-names "$repo_name" --region "$AWS_REGION" &> /dev/null; then
        echo "✅ ECR repository $repo_name already exists"
        return 0
    fi
    
    # Create repository
    if ! aws ecr create-repository --repository-name "$repo_name" --region "$AWS_REGION" &> /dev/null; then
        echo "❌ Failed to create ECR repository"
        return 1
    fi
    
    echo "✅ ECR repository created: $repo_name"
    return 0
}

# Function to update backend configuration
update_terraform_backend() {
    local bucket_name="$1"
    local backend_file="$2"
    
    echo "📝 Updating Terraform backend configuration..."
    
    if [ -f "$backend_file" ]; then
        # Use sed to replace the bucket name
        sed -i "s/bucket = \".*\"/bucket = \"$bucket_name\"/" "$backend_file"
        echo "✅ Backend configuration updated"
    else
        echo "⚠️ Backend file not found: $backend_file"
    fi
}

# Function to delete S3 bucket
remove_terraform_state_bucket() {
    local bucket_name="$1"
    
    echo "🗑️ Deleting S3 bucket: $bucket_name..."
    
    # Check if bucket exists
    if ! aws s3 ls "s3://$bucket_name" &> /dev/null; then
        echo "⚠️ Bucket $bucket_name does not exist"
        return 0
    fi
    
    # Empty bucket first (required before deletion)
    echo "🧹 Emptying bucket contents..."
    aws s3 rm "s3://$bucket_name" --recursive &> /dev/null
    
    # Delete all versions (for versioned buckets)
    aws s3api delete-objects --bucket "$bucket_name" \
        --delete "$(aws s3api list-object-versions --bucket "$bucket_name" \
        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null)" &> /dev/null
    
    aws s3api delete-objects --bucket "$bucket_name" \
        --delete "$(aws s3api list-object-versions --bucket "$bucket_name" \
        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null)" &> /dev/null
    
    # Delete bucket
    if ! aws s3 rb "s3://$bucket_name" &> /dev/null; then
        echo "❌ Failed to delete S3 bucket: $bucket_name"
        return 1
    fi
    
    echo "✅ S3 bucket deleted: $bucket_name"
    return 0
}

# Function to delete DynamoDB table
remove_dynamodb_lock_table() {
    local table_name="$1"
    
    echo "🗑️ Deleting DynamoDB table: $table_name..."
    
    # Check if table exists
    if ! aws dynamodb describe-table --table-name "$table_name" &> /dev/null; then
        echo "⚠️ DynamoDB table $table_name does not exist"
        return 0
    fi
    
    # Delete table
    if ! aws dynamodb delete-table --table-name "$table_name" --region "$AWS_REGION" &> /dev/null; then
        echo "❌ Failed to delete DynamoDB table: $table_name"
        return 1
    fi
    
    # Wait for table to be deleted
    echo "⏳ Waiting for DynamoDB table to be deleted..."
    while aws dynamodb describe-table --table-name "$table_name" &> /dev/null; do
        sleep 5
    done
    
    echo "✅ DynamoDB table deleted: $table_name"
    return 0
}

# Function to delete ECR repositories
remove_ecr_repositories() {
    local project_name="$1"
    
    echo "🔍 Finding ECR repositories to delete..."
    
    # List repositories matching project name
    local repositories=$(aws ecr describe-repositories --region "$AWS_REGION" \
        --query "repositories[?starts_with(repositoryName, '$project_name-')].repositoryName" \
        --output text 2>/dev/null)
    
    if [ -n "$repositories" ] && [ "$repositories" != "None" ]; then
        echo "$repositories" | tr '\t' '\n' | while read -r repo; do
            if [ -n "$repo" ]; then
                echo "🗑️ Deleting ECR repository: $repo..."
                if aws ecr delete-repository --repository-name "$repo" \
                    --region "$AWS_REGION" --force &> /dev/null; then
                    echo "✅ ECR repository deleted: $repo"
                else
                    echo "⚠️ Failed to delete ECR repository: $repo"
                fi
            fi
        done
    else
        echo "⚠️ No ECR repositories found matching: $project_name-*"
    fi
}

# Function to cleanup all resources
cleanup_resources() {
    echo "🧹 Starting cleanup process..."
    echo "⚠️ This will delete ALL resources created by this script!"
    
    if [ "$SKIP_CONFIRMATION" != "true" ]; then
        echo ""
        echo "Resources to be deleted:"
        echo "  - All S3 buckets matching pattern: terraform-state-$PROJECT_NAME-*"
        echo "  - DynamoDB table: terraform-locks"
        echo "  - ECR repositories matching: $PROJECT_NAME-* (with all images)"
        echo ""
        read -p "Are you sure you want to DELETE all these resources? Type 'DELETE' to confirm: " confirmation
        
        if [ "$confirmation" != "DELETE" ]; then
            echo "❌ Cleanup cancelled"
            return 0
        fi
    fi
    
    # Delete ECR repositories first (they might prevent Terraform destroy)
    remove_ecr_repositories "$PROJECT_NAME"
    
    # Find and delete S3 buckets
    echo "🔍 Finding S3 buckets to delete..."
    local buckets=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'terraform-state-$PROJECT_NAME-')].Name" --output text 2>/dev/null)
    
    if [ -n "$buckets" ] && [ "$buckets" != "None" ]; then
        echo "$buckets" | tr '\t' '\n' | while read -r bucket; do
            if [ -n "$bucket" ]; then
                remove_terraform_state_bucket "$bucket"
            fi
        done
    else
        echo "⚠️ No matching S3 buckets found"
    fi
    
    # Delete DynamoDB table
    local table_name="terraform-locks"
    remove_dynamodb_lock_table "$table_name"
    
    echo ""
    echo "🎉 Cleanup completed!"
    echo "💰 All AWS resources have been deleted to stop incurring costs."
    echo ""
    echo "📝 Don't forget to:"
    echo "   1. Remove GitHub repository secrets if no longer needed"
    echo "   2. Reset Terraform backend configuration if needed"
}

# Main execution function
main() {
    echo "🚀 GitHub Actions Prerequisites Setup for $PROJECT_NAME"
    echo "======================================================="
    
    # Handle help flag
    if [ "$MODE" = "--help" ] || [ "$MODE" = "-h" ] || [ -z "$MODE" ]; then
        show_usage
        return 0
    fi
    
    # Check for cleanup mode
    if [ "$MODE" = "cleanup" ]; then
        echo "🧹 GitHub Actions Cleanup for $PROJECT_NAME"
        echo "========================================="
        cleanup_resources
        return 0
    fi
    
    # Check for setup mode
    if [ "$MODE" = "setup" ]; then
        echo "🔍 Checking prerequisites..."
        
        if ! check_aws_setup; then
            exit 1
        fi
        
        # Generate unique names
        local bucket_name="terraform-state-$PROJECT_NAME-$RANDOM"
        local table_name="terraform-locks"
        local ecr_repo_name="$PROJECT_NAME-$ENVIRONMENT"
        
        echo ""
        echo "📋 Configuration:"
        echo "   Project: $PROJECT_NAME"
        echo "   Environment: $ENVIRONMENT"
        echo "   AWS Region: $AWS_REGION"
        echo "   S3 Bucket: $bucket_name"
        echo "   DynamoDB Table: $table_name"
        echo "   ECR Repository: $ecr_repo_name"
        echo ""
        
        if [ "$SKIP_CONFIRMATION" != "true" ]; then
            read -p "Continue with setup? (y/n): " confirmation
            if [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
                echo "❌ Setup cancelled"
                exit 0
            fi
        fi
        
        # Create resources
        local created_bucket
        if ! created_bucket=$(create_terraform_state_bucket "$bucket_name"); then
            exit 1
        fi
        
        if ! create_dynamodb_lock_table "$table_name"; then
            exit 1
        fi
        
        # Create ECR repository
        if ! create_ecr_repository "$ecr_repo_name"; then
            exit 1
        fi
        
        # Update Terraform backend
        local backend_file="$(dirname "$0")/terraform/backend.tf"
        update_terraform_backend "$created_bucket" "$backend_file"
        
        echo ""
        echo "🎉 Setup completed successfully!"
        echo "================================="
        echo ""
        echo "📊 Resources Created:"
        echo "   ✅ S3 Bucket: $created_bucket"
        echo "   ✅ DynamoDB Table: $table_name"
        echo "   ✅ ECR Repository: $ecr_repo_name"
        
        # Get ECR registry URL
        local aws_account
        if aws_account=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null); then
            local ecr_registry="$aws_account.dkr.ecr.$AWS_REGION.amazonaws.com"
            echo "   📦 ECR Registry: $ecr_registry"
        fi
        echo ""
        
        echo "🔐 GitHub Repository Secrets:"
        echo "   Add these secrets to your GitHub repository:"
        echo "   Settings → Secrets and variables → Actions → New repository secret"
        echo ""
        echo "   AWS_ACCESS_KEY_ID = [Your existing AWS Access Key ID]"
        echo "   AWS_SECRET_ACCESS_KEY = [Your existing AWS Secret Access Key]"
        echo "   TERRAFORM_STATE_BUCKET = $created_bucket"
        echo ""
        echo "💡 Use your existing AWS credentials from 'aws configure'"
        
        echo ""
        echo "🚀 Next Steps:"
        echo "   1. Add the above secrets to your GitHub repository"
        echo "   2. Run 'terraform init' in the terraform directory"
        echo "   3. Test your GitHub Actions workflows"
        echo "   4. Create additional environments as needed"
        echo ""
        echo "💡 GitHub Actions URL: https://github.com/your-username/your-repo/actions"
        return 0
    fi
    
    # Invalid mode
    echo "❌ Invalid mode: $MODE"
    echo "Use 'setup' or 'cleanup'. Run with --help for usage information."
    exit 1
}

# Script usage information
show_usage() {
    echo "🚀 GitHub Actions Prerequisites Setup for $PROJECT_NAME"
    echo "======================================================="
    echo ""
    echo "Usage: $0 [MODE] [PROJECT_NAME] [AWS_REGION] [SKIP_CONFIRMATION]"
    echo ""
    echo "Modes:"
    echo "  setup     - Create AWS resources (S3 bucket, DynamoDB table)"
    echo "  cleanup   - Delete all resources created by this script (DESTRUCTIVE)"
    echo ""
    echo "Parameters:"
    echo "  PROJECT_NAME      - Name of your project (default: kudos-app)"
    echo "  AWS_REGION        - AWS region to use (default: us-east-1)"
    echo "  SKIP_CONFIRMATION - Set to 'true' to skip confirmation prompts"
    echo ""
    echo "Examples:"
    echo "  $0 setup                              # Setup with defaults"
    echo "  $0 setup my-app                       # Custom project name"
    echo "  $0 setup my-app us-west-2             # Custom project and region"
    echo "  $0 setup my-app us-west-2 true        # Skip confirmations"
    echo "  $0 cleanup                            # Delete all resources"
    echo "  PROJECT_NAME=my-app $0 cleanup        # Cleanup specific project"
    echo ""
}

# Execute main function
main