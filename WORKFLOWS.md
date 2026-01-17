# Kudos App - AWS EKS Deployment Workflows

This repository provides **three simple workflows** to deploy your React application to Amazon EKS. Each workflow has a specific purpose and clear instructions.

## 🎯 **Workflows Overview**

| **Workflow** | **Purpose** | **When to Use** |
|--------------|-------------|-----------------|
| [`create-infrastructure.sh`](create-infrastructure.sh) | Create EKS cluster and AWS infrastructure | First time setup or after cleanup |
| [`deploy-app.sh`](deploy-app.sh) | Deploy/update your React app | Every time you want to deploy or update your app |
| [`destroy-infrastructure.sh`](destroy-infrastructure.sh) | Clean up and delete everything | When done to avoid AWS charges |

## 🚀 **Quick Start (3 Commands)**

```bash
# 1. Create the infrastructure (15-20 minutes)
./create-infrastructure.sh

# 2. Deploy your app (3-5 minutes)  
./deploy-app.sh

# 3. When done, clean up to save money
./destroy-infrastructure.sh
```

## 📋 **Prerequisites**

Install these tools before starting:
- [AWS CLI](https://aws.amazon.com/cli/) - `aws configure` with your credentials
- [Terraform](https://www.terraform.io/downloads) - Infrastructure automation
- [Docker](https://www.docker.com/products/docker-desktop) - Container building
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes management

## 🏗️ **Workflow 1: Create Infrastructure**

**File:** `create-infrastructure.sh`
**Time:** 15-20 minutes
**Cost:** ~$150/month while running

### What it creates:
- ✅ EKS Kubernetes cluster
- ✅ VPC with public/private subnets  
- ✅ 2 t3.medium worker nodes
- ✅ ECR container registry
- ✅ All necessary security groups and IAM roles

### Usage:
```bash
chmod +x create-infrastructure.sh
./create-infrastructure.sh
```

### What happens:
1. 🔍 Checks prerequisites and AWS connection
2. 📦 Initializes Terraform
3. 📋 Shows you what will be created
4. ⏳ Creates infrastructure (coffee break time!)
5. 🔧 Configures your kubectl access
6. ✅ Provides summary of created resources

## 🚀 **Workflow 2: Deploy Application**

**File:** `deploy-app.sh`  
**Time:** 3-5 minutes
**Prerequisites:** Infrastructure must exist (run workflow 1 first)

### What it does:
- 🐳 Builds your React app into a Docker container
- 📤 Uploads it to your private ECR registry
- 🚀 Deploys it to Kubernetes (2 replicas for reliability)
- 🌐 Creates a public load balancer URL
- ✅ Provides health checks and monitoring

### Usage:
```bash
chmod +x deploy-app.sh
./deploy-app.sh
```

### What happens:
1. 🔍 Verifies infrastructure and cluster connection
2. 🏗️ Builds Docker image from your code
3. 📤 Uploads to your private container registry
4. 🚀 Deploys to Kubernetes with load balancer
5. ⏳ Waits for deployment to be ready
6. 🌐 Provides your app's public URL

### To update your app:
Just run `./deploy-app.sh` again after making code changes!

## 🗑️ **Workflow 3: Destroy Infrastructure**

**File:** `destroy-infrastructure.sh`
**Time:** 10-15 minutes
**Purpose:** Clean up to avoid ongoing AWS charges

### What it destroys:
- 🗑️ Entire EKS cluster
- 🗑️ All worker nodes  
- 🗑️ VPC and networking
- 🗑️ ECR repository and images
- 🗑️ All security groups and IAM roles

### Usage:
```bash
chmod +x destroy-infrastructure.sh
./destroy-infrastructure.sh
```

**⚠️ WARNING:** This cannot be undone! Your app and data will be lost.

## 📊 **Understanding the Workflows**

### **Separation Benefits:**
1. **Clear responsibilities** - Each script has one job
2. **Faster iteration** - Rebuild app without touching infrastructure  
3. **Cost control** - Keep infrastructure, just redeploy app
4. **Learning friendly** - Understand each phase separately

### **Typical Development Cycle:**
```bash
# One-time setup
./create-infrastructure.sh

# Development cycle (repeat as needed)
# Make code changes...
./deploy-app.sh
# Test your app...
./deploy-app.sh
# More changes...
./deploy-app.sh

# When completely done
./destroy-infrastructure.sh
```

## 💰 **Cost Management**

### **Monthly Costs (while running):**
- EKS Cluster: ~$75
- 2 t3.medium nodes: ~$60  
- Load Balancer: ~$23
- Networking: ~$15
- **Total: ~$173/month**

### **Cost Saving Tips:**
- ✅ Run `./destroy-infrastructure.sh` when not using
- ✅ Use workflow 2 for quick app updates (no infrastructure cost)
- ✅ Monitor AWS billing dashboard
- ⚠️ Don't forget running resources!

## 🔧 **Advanced Usage**

### **Multiple Apps:**
You can deploy different versions of your app:
```bash
# Deploy version 1
./deploy-app.sh

# Make changes, deploy version 2  
./deploy-app.sh
# Kubernetes automatically does rolling update!
```

### **Monitoring Your App:**
```bash
# See app status
kubectl get pods

# See app logs
kubectl logs -l app=kudos-app -f

# See public URL
kubectl get svc kudos-app-service

# Scale up (run more copies)
kubectl scale deployment kudos-app --replicas=5
```

### **Troubleshooting:**
```bash
# Check cluster health
kubectl get nodes

# Check app health  
kubectl describe deployment kudos-app

# Check specific pod issues
kubectl describe pod <pod-name>

# Restart deployment
kubectl rollout restart deployment/kudos-app
```

## 🎓 **Teaching Guide**

Perfect for teaching because:

### **Logical Progression:**
1. **Infrastructure First** - Build the foundation
2. **Application Second** - Deploy the actual app  
3. **Cleanup Third** - Responsible resource management

### **Learning Objectives:**
- Understand infrastructure vs application deployment
- See the power of automation with scripts
- Learn Kubernetes basics through practical deployment
- Understand cloud cost management

### **Workshop Timeline:**
- **30 min**: Explain concepts and prerequisites
- **20 min**: Run workflow 1 (coffee break during creation)
- **10 min**: Run workflow 2 and see live app
- **15 min**: Explore monitoring and scaling
- **5 min**: Run workflow 3 for cleanup

## 📚 **What Students Learn**

1. **Infrastructure as Code** - Terraform basics
2. **Container Orchestration** - Kubernetes fundamentals  
3. **CI/CD Concepts** - Automated deployment pipelines
4. **Cloud Architecture** - VPC, subnets, load balancers
5. **Cost Management** - Responsible cloud usage
6. **Real-world Skills** - Industry-standard tools and practices

This workflow-based approach makes complex cloud deployment accessible to anyone while teaching real-world, professional practices!