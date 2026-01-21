# 🚀 GitHub Actions Setup Guide

This guide helps you set up automated infrastructure management using GitHub Actions.

## 📋 Prerequisites

1. **GitHub Repository** with this code
2. **AWS Account** with appropriate permissions
3. **S3 Bucket** for Terraform state storage
4. **DynamoDB Table** for state locking (optional but recommended)

## 🔧 Setup Steps

### 1️⃣ Create S3 Bucket for Terraform State

```bash
# Replace 'your-unique-bucket-name' with your actual bucket name
aws s3 mb s3://your-terraform-state-bucket-kudos-app --region us-east-1

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket-kudos-app \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket-kudos-app \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 2️⃣ Create DynamoDB Table for State Locking (Optional)

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region us-east-1
```

### 3️⃣ Create IAM User for GitHub Actions (COMMENTED OUT - NOT NEEDED)

<!-- 
```bash
# Create user
aws iam create-user --user-name github-actions-terraform

# Create and attach policy
cat > github-actions-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "iam:*",
        "ecr:*",
        "s3:*",
        "dynamodb:*",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-user-policy \
  --user-name github-actions-terraform \
  --policy-name TerraformAccess \
  --policy-document file://github-actions-policy.json

# Create access keys
aws iam create-access-key --user-name github-actions-terraform
```
-->

### 4️⃣ Set GitHub Repository Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these **Repository Secrets**:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | From your existing AWS credentials |
| `AWS_SECRET_ACCESS_KEY` | `xxxxx...` | From your existing AWS credentials |
| `TERRAFORM_STATE_BUCKET` | `your-terraform-state-bucket-kudos-app` | S3 bucket name |

### 5️⃣ Create GitHub Environments (Optional)

For additional security, create environments:
1. Go to Settings → Environments
2. Create environments: `dev`, `staging`, `prod`
3. Add protection rules (required reviewers, wait timer, etc.)

## 🎮 How to Use the Workflows

### 🏗️ Infrastructure Management

1. Go to **Actions** tab in your repository
2. Select **🏗️ Infrastructure Management** workflow
3. Click **Run workflow**
4. Choose options:
   - **Action**: `plan`, `apply`, or `destroy`
   - **Environment**: `dev`, `staging`, or `prod`
   - **Auto-approve**: Check for automatic execution

### 🐳 Docker Build & Deploy

1. **Automatic**: Triggered on push to `main` branch
2. **Manual**: 
   - Go to **Actions** tab
   - Select **🐳 Docker Build & Deploy**
   - Click **Run workflow**
   - Choose environment and options

## 🔄 Typical Workflows

### First Time Setup
```
1. Run Infrastructure workflow with "plan" action
2. Review the plan
3. Run Infrastructure workflow with "apply" action (auto-approve: true)
4. Run Docker Build & Deploy workflow
```

### Regular Updates
```
1. Push code changes to main branch (auto-triggers Docker workflow)
2. Or manually trigger Infrastructure workflow for infrastructure changes
```

### Environment Management
```
1. Create infrastructure for each environment separately
2. Use different app names per environment (kudos-app-dev, kudos-app-prod)
3. Deploy different image tags to different environments
```

## 🔍 Monitoring and Troubleshooting

### View Terraform State
```bash
# List state bucket contents
aws s3 ls s3://your-terraform-state-bucket-kudos-app/

# Download state file locally (for inspection only)
aws s3 cp s3://your-terraform-state-bucket-kudos-app/kudos-app/dev/terraform.tfstate ./
```

### Check EKS Cluster
```bash
# Connect to cluster
aws eks update-kubeconfig --region us-east-1 --name kudos-app-dev

# Check status
kubectl get all
kubectl get nodes
```

### View ECR Images
```bash
# List images
aws ecr list-images --repository-name kudos-app --region us-east-1
```

## 🛡️ Security Best Practices

### ✅ Implemented
- Terraform state stored in encrypted S3
- State locking via DynamoDB
- IAM user with minimal required permissions
- GitHub secrets for sensitive data
- Environment-based deployments

### 🔧 Additional Recommendations
- Enable GitHub branch protection rules
- Use environment-specific AWS accounts
- Implement cost monitoring and alerts
- Set up log monitoring for applications
- Regular security scanning of Docker images

## 📊 Cost Management

### Current Setup Costs (Estimated per month)
- **EKS Cluster**: $73.00 (control plane)
- **t3.small node**: ~$15.00
- **LoadBalancer**: ~$18.00
- **S3 + DynamoDB**: ~$1.00
- **ECR storage**: ~$1.00 (depends on images)

**Total**: ~$108/month per environment

### Cost Optimization Tips
- Use t3.small or t3.micro instances for dev
- Stop dev infrastructure overnight using scheduled workflows
- Clean up old ECR images regularly
- Monitor AWS Cost Explorer regularly

## 🚨 Important Notes

⚠️ **State File Security**: Never commit `.tfstate` files to Git
⚠️ **Secrets Management**: Always use GitHub secrets for sensitive data
⚠️ **Resource Naming**: Use consistent naming with environment prefixes
⚠️ **Permissions**: Start with minimal permissions and add as needed

## 🎯 Next Steps

1. Set up the infrastructure following this guide
2. Test the workflows in the `dev` environment
3. Create additional environments as needed
4. Set up monitoring and alerting
5. Implement automated testing in the pipeline

Happy automating! 🚀