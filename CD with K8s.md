# CD with K8s - Complete Deployment Guide

This guide covers the complete process of deploying the Kudos App to AWS EKS using Terraform for infrastructure provisioning and Kubernetes for orchestration.

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- Docker Desktop installed and running
- Terraform installed
- kubectl installed
- Git repository with the application code

## 🏗️ Infrastructure Setup with Terraform

### Step 1: Navigate to Terraform Directory
```powershell
cd terraform
```

### Step 2: Review and Optimize Terraform Configuration

The Terraform configuration was optimized for cost-effectiveness:
- **Instance Type**: Changed from `t3.medium` to `t3.small` (50% cost savings)
- **Node Count**: Reduced from 2 to 1 worker node (50% compute cost savings)
- **Network**: Simplified to use public subnets only (eliminates $45/month NAT gateway costs)
- **Availability Zones**: Uses 2 AZs as required by EKS

### Step 3: Plan Infrastructure
```powershell
terraform plan
```

### Step 4: Deploy Infrastructure
```powershell
terraform apply --auto-approve
```

**Expected Output:**
```
Apply complete! Resources: 14 added, 0 changed, 0 destroyed.

Outputs:
cluster_name = "kudos-app"
ecr_repository_url = "036983629554.dkr.ecr.us-east-1.amazonaws.com/kudos-app"
how_to_connect = "aws eks --region us-east-1 update-kubeconfig --name kudos-app"
vpc_id = "vpc-09bbc8f0cc954d162"
```

## 🐳 Docker Image Management

### Step 5: Login to ECR
```powershell
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 036983629554.dkr.ecr.us-east-1.amazonaws.com
```

### Step 6: Build Docker Image
```powershell
docker build -t kudos-app .
```

### Step 7: Tag Image for ECR
```powershell
docker tag kudos-app:latest 036983629554.dkr.ecr.us-east-1.amazonaws.com/kudos-app:latest
```

### Step 8: Push Image to ECR
```powershell
docker push 036983629554.dkr.ecr.us-east-1.amazonaws.com/kudos-app:latest
```

## ☸️ Kubernetes Deployment

### Step 9: Connect to EKS Cluster
```powershell
aws eks --region us-east-1 update-kubeconfig --name kudos-app
```

### Step 10: Verify Node Readiness
```powershell
kubectl get nodes
```

**Expected Output:**
```
NAME                        STATUS   ROLES    AGE   VERSION
ip-10-0-2-58.ec2.internal   Ready    <none>   26m   v1.34.2-eks-ecaa3a6
```

### Step 11: Update Kubernetes Manifests

**Deployment Configuration (k8s/deployment.yaml):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kudos-frontend
  labels:
    app: kudos-frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kudos-frontend
  template:
    metadata:
      labels:
        app: kudos-frontend
    spec:
      containers:
        - name: kudos-frontend
          image: 036983629554.dkr.ecr.us-east-1.amazonaws.com/kudos-app:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 80
          resources:
            requests: 
              cpu: "100m"
              memory: "128Mi" 
            limits:
              cpu: "500m"
              memory: "512Mi"
```

**Service Configuration (k8s/service.yaml):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: kudos-frontend
spec:
  type: LoadBalancer  # Creates AWS load balancer for external access
  selector:
    app: kudos-frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

### Step 12: Deploy to Kubernetes
```powershell
kubectl apply -f k8s/
```

**Expected Output:**
```
deployment.apps/kudos-frontend created
horizontalpodautoscaler.autoscaling/kudos-frontend-hpa created
ingress.networking.k8s.io/kudos-frontend created
service/kudos-frontend created
```

## 🌐 Application Verification

### Step 13: Get Service Details
```powershell
kubectl get service kudos-frontend
```

**Expected Output:**
```
NAME             TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)        AGE
kudos-frontend   LoadBalancer   172.20.232.65   a0eb2005bf58c48618522f0ef2fe961a-2100235228.us-east-1.elb.amazonaws.com   80:30877/TCP   4m26s
```

### Step 14: Test Application Access
```powershell
curl http://a0eb2005bf58c48618522f0ef2fe961a-2100235228.us-east-1.elb.amazonaws.com
```

**Expected Output:**
```
StatusCode        : 200
StatusDescription : OK
Content           : <!DOCTYPE html>
                    <html lang="en">
                      <head>
                        <meta charset="UTF-8" />
                        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
                        <title>Kudos App</title>
```

### Step 15: Check All Kubernetes Resources
```powershell
kubectl get all
```

## 🔍 Troubleshooting Commands

### Check Pod Status and Logs
```powershell
# Get pod status
kubectl get pods

# Check pod logs
kubectl logs -l app=kudos-frontend

# Describe pod for detailed info
kubectl describe pod <pod-name>
```

### Check Service and Endpoints
```powershell
# Check service details
kubectl describe service kudos-frontend

# Check endpoints
kubectl get endpoints kudos-frontend
```

### Scale Application
```powershell
# Scale up/down
kubectl scale deployment kudos-frontend --replicas=2
```

## 💰 Cost Optimization Features

### Infrastructure Optimizations Applied:
- **t3.small instances** instead of t3.medium (50% cost reduction)
- **Single node** for development (50% compute cost savings)
- **Public subnets only** (eliminates NAT gateway costs ~$45/month)
- **Minimal resources** in Kubernetes deployment

### Estimated Monthly Costs:
- **Before optimization**: ~$150-200/month
- **After optimization**: ~$50-75/month
- **Cost savings**: 60-70% reduction

## 🚀 Application Access

**Public URL**: `http://a0eb2005bf58c48618522f0ef2fe961a-2100235228.us-east-1.elb.amazonaws.com`

The application is now fully deployed and accessible from the internet through the AWS Load Balancer.

## 🧹 Cleanup (When Done)

To destroy all resources and avoid charges:

```powershell
# Delete Kubernetes resources
kubectl delete -f k8s/

# Destroy Terraform infrastructure
cd terraform
terraform destroy --auto-approve
```

## 📁 Project Structure

```
├── terraform/
│   ├── main.tf
│   ├── cluster.tf
│   ├── vpc.tf
│   ├── ecr.tf
│   ├── variables.tf
│   └── outputs.tf
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── hpa.yaml
│   └── ingress.yaml
├── Dockerfile
├── package.json
└── CD with K8s.md
```

## ✅ Success Checklist

- [ ] Terraform infrastructure deployed (EKS cluster, ECR, VPC)
- [ ] Docker image built and pushed to ECR
- [ ] EKS cluster connected via kubectl
- [ ] Kubernetes manifests deployed
- [ ] LoadBalancer service created with external IP
- [ ] Application accessible via public URL
- [ ] HTTP 200 response confirmed

## 📝 Key Learnings

1. **EKS requires subnets in at least 2 AZs** for high availability
2. **Docker Desktop must be running** before ECR login attempts
3. **LoadBalancer service type** automatically creates AWS ELB for external access
4. **Public subnets** can significantly reduce costs by eliminating NAT gateway needs
5. **Resource limits** in Kubernetes help with cost control and performance