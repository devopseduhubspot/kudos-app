# 🚀 Complete Kudos App Deployment Guide - From Zero to Production

This comprehensive guide takes you from scratch to a fully deployed Kudos application on AWS EKS, covering every single step in sequence.

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [AWS Infrastructure Setup](#aws-infrastructure-setup)
4. [GitHub Repository Configuration](#github-repository-configuration)
5. [Infrastructure Deployment](#infrastructure-deployment)
6. [Application Deployment](#application-deployment)
7. [Verification & Testing](#verification--testing)
8. [Cleanup Process](#cleanup-process)

---

## 1. Prerequisites

### ✅ Required Software
```bash
# Check if required tools are installed
aws --version          # AWS CLI v2.x
node --version         # Node.js 18+
npm --version          # npm 8+
docker --version       # Docker 20+
git --version          # Git 2.x
kubectl version        # kubectl 1.29+
```

### 📦 Installation Commands

**Windows (PowerShell as Administrator):**
```powershell
# Install Chocolatey package manager
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install required tools
choco install awscli nodejs docker-desktop git kubernetes-cli -y
```

**Linux/WSL:**
```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Node.js (via NodeSource)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

---

## 2. Initial Setup

### 🔐 AWS Account Setup
1. **Create AWS Account**: https://aws.amazon.com/
2. **Create IAM User**:
   ```bash
   # Go to AWS Console → IAM → Users → Create User
   # User Name: github-actions-user
   # Attach Policy: AdministratorAccess (for demo - use minimal permissions in production)
   ```

3. **Configure AWS CLI**:
   ```bash
   aws configure
   # AWS Access Key ID: [Your Access Key]
   # AWS Secret Access Key: [Your Secret Key] 
   # Default region name: us-east-1
   # Default output format: json
   ```

4. **Verify AWS Setup**:
   ```bash
   aws sts get-caller-identity
   ```

### 📂 Clone Repository
```bash
git clone https://github.com/your-username/kudos-app.git
cd kudos-app
```

---

## 3. AWS Infrastructure Setup

### 🎯 Option A: Automated Setup (Recommended)

**Windows:**
```powershell
# Navigate to project directory
cd C:\path\to\kudos-app

# Run setup script for dev environment
.\Setup-GitHubActions-Clean.ps1 -Environment "dev"

# For production environment
.\Setup-GitHubActions-Clean.ps1 -Environment "prod" -AWSRegion "us-west-2"
```

**Linux/WSL:**
```bash
# Make script executable
chmod +x Setup-GitHubActions.sh

# Run setup for dev environment
./Setup-GitHubActions.sh setup kudos-app us-east-1 dev

# For production environment  
./Setup-GitHubActions.sh setup kudos-app us-west-2 prod
```

### 📝 What Gets Created:
- ✅ **S3 Bucket**: `terraform-state-kudos-app-{random}` (encrypted, versioned)
- ✅ **DynamoDB Table**: `terraform-locks` (state locking)
- ✅ **ECR Repository**: `kudos-app-dev` (container registry)

### 🎯 Option B: Manual Setup

<details>
<summary>Click to expand manual setup steps</summary>

```bash
# 1. Create S3 bucket for Terraform state
aws s3 mb s3://terraform-state-kudos-app-$(date +%s) --region us-east-1

# 2. Enable S3 versioning
aws s3api put-bucket-versioning --bucket [bucket-name] --versioning-configuration Status=Enabled

# 3. Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region us-east-1

# 4. Create ECR repository
aws ecr create-repository --repository-name kudos-app-dev --region us-east-1
```

</details>

---

## 4. GitHub Repository Configuration

### 🔐 GitHub Secrets Setup

1. **Navigate to GitHub Repository**:
   ```
   https://github.com/your-username/kudos-app
   Settings → Secrets and variables → Actions → New repository secret
   ```

2. **Add Required Secrets**:
   ```
   Name: AWS_ACCESS_KEY_ID
   Value: [Your AWS Access Key ID]

   Name: AWS_SECRET_ACCESS_KEY  
   Value: [Your AWS Secret Access Key]

   Name: TERRAFORM_STATE_BUCKET
   Value: [S3 bucket name from setup script output]

   Name: SNYK_TOKEN (Optional - for security scanning)
   Value: [Get from https://app.snyk.io/account]
   ```

### 🌍 Environment Setup
1. **Go to**: Settings → Environments → New environment
2. **Create environments**: `dev`, `staging`, `prod`
3. **Add protection rules** (optional for production)

---

## 5. Infrastructure Deployment

### 🏗️ Deploy EKS Infrastructure

**Option A: Via GitHub Actions (Recommended)**
1. Go to **Actions** → **Infrastructure Management**
2. Click **Run workflow**
3. Configure:
   ```
   Action: apply
   Environment: dev  
   Auto-approve: ✅ true
   ```
4. Click **Run workflow**

**Option B: Via Terraform CLI**
```bash
cd terraform

# Initialize Terraform
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=kudos-app/dev/terraform.tfstate" \
  -backend-config="region=us-east-1"

# Plan infrastructure
terraform plan -var="app_name=kudos-app-dev"

# Apply infrastructure (creates EKS cluster - takes 10-15 minutes)
terraform apply -var="app_name=kudos-app-dev" -auto-approve
```

### ⏱️ Infrastructure Creation Timeline:
- **S3/DynamoDB/ECR**: ~2 minutes
- **VPC/Networking**: ~3 minutes  
- **EKS Cluster**: ~10-15 minutes
- **Node Groups**: ~5 minutes
- **Total**: ~20-25 minutes

### 📊 Expected Resources Created:
- ✅ **VPC** with public/private subnets
- ✅ **EKS Cluster**: `kudos-app-dev`
- ✅ **Node Group**: 2x t3.small instances
- ✅ **Security Groups** and **IAM Roles**
- ✅ **Application Load Balancer**

---

## 6. Application Deployment

### 🚀 Deploy Kudos Application

**Method A: GitHub Actions (Recommended)**
1. Go to **Actions** → **main-ci-cd-manual**
2. Click **Run workflow**
3. Configure:
   ```
   Environment: dev
   Mode: full-pipeline
   ```
4. Click **Run workflow**

**Method B: Manual Deployment**
```bash
# 1. Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name kudos-app-dev

# 2. Verify cluster connection
kubectl cluster-info
kubectl get nodes

# 3. Build and push Docker image
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

docker build -t $ECR_REGISTRY/kudos-app-dev:latest .
docker push $ECR_REGISTRY/kudos-app-dev:latest

# 4. Update Kubernetes manifests
sed -i "s|image:.*|image: $ECR_REGISTRY/kudos-app-dev:latest|" k8s/deployment.yaml

# 5. Deploy to Kubernetes
kubectl apply -k k8s/
```

### 📋 Deployment Pipeline Steps:
1. **📦 Install Dependencies** (npm ci)
2. **🔍 Lint Code** (ESLint)
3. **🧪 Run Tests** (Jest)
4. **🛡️ Security Scan** (Snyk)
5. **🏗️ Build Application** (npm run build)
6. **🐳 Build & Push Docker Image** (4 tags):
   - `latest`
   - `{commit-sha}`
   - `{branch}-latest`
   - `{branch}-{datetime}`
7. **🔍 Container Security Scan** (Trivy)
8. **☸️ Deploy to EKS**
9. **🏥 Health Checks**
10. **📊 Generate Reports**

---

## 7. Verification & Testing

### ✅ Verify Deployment

```bash
# 1. Check cluster status
kubectl get nodes
kubectl get deployments
kubectl get pods
kubectl get services

# 2. Check application pods
kubectl get pods -l app=kudos-frontend
kubectl logs -l app=kudos-frontend

# 3. Get service details
kubectl get service kudos-frontend

# 4. Port forward to test locally
kubectl port-forward svc/kudos-frontend 8080:80

# 5. Test application (in another terminal)
curl http://localhost:8080
```

### 🌐 Access Application

**Option A: Load Balancer (if configured)**
```bash
# Get external IP
kubectl get service kudos-frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Option B: Port Forward**
```bash
kubectl port-forward svc/kudos-frontend 8080:80
# Access: http://localhost:8080
```

### 🔍 Troubleshooting Commands

```bash
# Check pod status
kubectl describe pod [pod-name]

# View pod logs
kubectl logs [pod-name] -f

# Check service endpoints
kubectl get endpoints kudos-frontend

# Restart deployment
kubectl rollout restart deployment/kudos-frontend

# Check cluster events
kubectl get events --sort-by='.lastTimestamp'
```

---

## 8. Cleanup Process

### 🧹 Complete Cleanup (DESTRUCTIVE)

**⚠️ Warning**: This will delete ALL resources and incur no further costs.

**Windows:**
```powershell
# Clean up application and infrastructure
.\Setup-GitHubActions-Clean.ps1 -Cleanup -SkipConfirmation
```

**Linux/WSL:**
```bash
# Clean up all resources
./Setup-GitHubActions.sh cleanup kudos-app us-east-1 dev true
```

**Manual Cleanup:**
```bash
# 1. Delete Kubernetes resources
kubectl delete -k k8s/

# 2. Destroy infrastructure via GitHub Actions
# Actions → Infrastructure Management → Run workflow
# Action: destroy, Environment: dev, Auto-approve: true

# 3. Or via Terraform CLI
cd terraform
terraform destroy -var="app_name=kudos-app-dev" -auto-approve

# 4. Clean up remaining resources
aws ecr delete-repository --repository-name kudos-app-dev --force --region us-east-1
aws s3 rb s3://your-terraform-bucket --force
aws dynamodb delete-table --table-name terraform-locks --region us-east-1
```

---

## 📊 Cost Estimation

### 💰 Monthly Costs (us-east-1):

**Development Environment:**
- **EKS Cluster**: ~$73/month (control plane)
- **EC2 Instances**: ~$30/month (2x t3.small)
- **Load Balancer**: ~$18/month
- **S3 Storage**: ~$0.50/month
- **DynamoDB**: ~$1.50/month
- **ECR Storage**: ~$1/month (per GB)
- **Total**: ~$124/month

**Production Environment:**
- **EKS Cluster**: ~$73/month
- **EC2 Instances**: ~$60/month (2x t3.medium)
- **Load Balancer**: ~$18/month
- **NAT Gateway**: ~$32/month
- **Other services**: ~$5/month
- **Total**: ~$188/month

### 💡 Cost Optimization Tips:
- Use **Spot Instances** for dev environments (-50-90% cost)
- Enable **Cluster Autoscaler** to scale down when not in use
- Use **t3.micro** instances for testing (free tier eligible)
- **Delete dev environments** when not in use

---

## 🎯 Quick Command Reference

### Essential Commands:
```bash
# Check AWS connection
aws sts get-caller-identity

# Check kubectl connection  
kubectl cluster-info

# Check application status
kubectl get all -l app=kudos-frontend

# View application logs
kubectl logs -l app=kudos-frontend -f

# Restart application
kubectl rollout restart deployment/kudos-frontend

# Access application locally
kubectl port-forward svc/kudos-frontend 8080:80
```

### GitHub Actions URLs:
- **Infrastructure Management**: `https://github.com/your-username/kudos-app/actions/workflows/infrastructure.yml`
- **Application Deployment**: `https://github.com/your-username/kudos-app/actions/workflows/main-ci-cd-manual.yml`

---

## 🆘 Common Issues & Solutions

### Issue: EKS Cluster Not Found
```bash
# Solution: Verify cluster name and region
aws eks describe-cluster --name kudos-app-dev --region us-east-1
```

### Issue: Docker Image Not Found
```bash
# Solution: Check ECR repository
aws ecr describe-repositories --region us-east-1
aws ecr list-images --repository-name kudos-app-dev --region us-east-1
```

### Issue: Pods Not Starting
```bash
# Check pod status and events
kubectl describe pod [pod-name]
kubectl get events --sort-by='.lastTimestamp'
```

### Issue: GitHub Actions Failing
1. **Check secrets**: Ensure all required secrets are set
2. **Check permissions**: IAM user needs appropriate permissions
3. **Check cluster**: Ensure EKS cluster exists and is accessible

---

## ✅ Success Checklist

- [ ] AWS CLI configured and working
- [ ] GitHub repository forked/cloned
- [ ] GitHub secrets configured
- [ ] Infrastructure deployed successfully
- [ ] Application deployed successfully
- [ ] Application accessible via browser/curl
- [ ] All tests passing in CI/CD pipeline
- [ ] Monitoring and logging working
- [ ] Cleanup process tested

---

## 🎉 Congratulations!

You now have a complete, production-ready Kubernetes application running on AWS EKS with:
- ✅ **Automated CI/CD pipelines**
- ✅ **Multi-environment support** (dev/staging/prod)
- ✅ **Container security scanning**
- ✅ **Infrastructure as Code**
- ✅ **Zero-downtime deployments**
- ✅ **Monitoring and logging**
- ✅ **Automated cleanup processes**

Your Kudos application is ready for production use! 🚀

---

*Last updated: January 21, 2026*
*For issues or contributions, please create a GitHub issue or pull request.*