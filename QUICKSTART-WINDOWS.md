# Quick Start Guide - Windows

## Prerequisites
1. Install [AWS CLI](https://aws.amazon.com/cli/) and run `aws configure`
2. Install [Terraform](https://www.terraform.io/downloads)
3. Install [Docker Desktop](https://www.docker.com/products/docker-desktop)
4. Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)

## Three Simple Commands (PowerShell)

### 1. Create Infrastructure (15-20 minutes)
```powershell
.\create-infrastructure.ps1
```

### 2. Deploy Your App (3-5 minutes)
```powershell
.\deploy-app.ps1
```

### 3. Clean Up (when done)
```powershell
.\destroy-infrastructure.ps1
```

## What Gets Created
- **EKS Cluster**: Managed Kubernetes cluster
- **VPC**: Private network with public/private subnets
- **ECR Repository**: Private Docker registry
- **Worker Nodes**: 2 t3.medium instances
- **Load Balancer**: Public access to your app

## Cost: ~$150/month while running

## Troubleshooting

### "Execution policy" error:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "AWS not configured":
```powershell
aws configure
```

### "Docker not running":
- Start Docker Desktop application

### "kubectl not found":
- Install from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/

## Files Created
- `create-infrastructure.ps1` - Creates AWS infrastructure  
- `deploy-app.ps1` - Deploys your React app
- `destroy-infrastructure.ps1` - Cleans up everything
- `terraform/` - Infrastructure code

## For Linux/Mac Users
Use the `.sh` versions instead:
- `./create-infrastructure.sh`
- `./deploy-app.sh` 
- `./destroy-infrastructure.sh`