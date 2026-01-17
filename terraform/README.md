# Simple Terraform Tutorial - Deploy a Web App to AWS

This is a beginner-friendly guide to deploy your React app to Amazon Web Services (AWS) using Terraform.

## What This Does

This Terraform configuration creates:
- **A Kubernetes cluster** - A computer system that runs your app
- **A container registry** - A place to store your packaged app
- **A private network** - Secure networking for your app

## What You Need

1. **AWS Account** - Sign up at https://aws.amazon.com/
2. **AWS CLI** - Download from https://aws.amazon.com/cli/
3. **Terraform** - Download from https://www.terraform.io/downloads
4. **Docker** - Download from https://www.docker.com/products/docker-desktop

## Files Explained (For Teaching)

### 📁 `main.tf`
This is the "starting point". It tells Terraform:
- Which cloud provider to use (AWS)
- Which region to deploy to (Virginia - us-east-1)

### 📁 `variables.tf`
This contains "settings" you can change:
- `app_name` - The name of your application

### 📁 `vpc.tf`
This creates your "private network" in the cloud:
- **VPC** - Your private space in AWS
- **Subnets** - Sections of your network (public and private)
- **Internet Gateway** - Connects your network to the internet
- **Route Table** - Tells traffic where to go

### 📁 `ecr.tf`
This creates a "container registry":
- A secure place to store your packaged app
- Like a private Docker Hub just for you

### 📁 `cluster.tf`
This creates your "Kubernetes cluster":
- **EKS Cluster** - The management system
- **Node Group** - The actual computers (2 medium-sized servers)
- **IAM Roles** - Permissions for everything to work together

### 📁 `outputs.tf`
This shows important information after deployment:
- Cluster name
- Registry URL
- How to connect to your cluster

## How to Deploy (Simple Way)

1. **Prepare your configuration:**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Run the deployment script:**
   ```bash
   chmod +x simple-deploy.sh
   ./simple-deploy.sh
   ```

3. **Follow the prompts!** The script will:
   - Check if you have required tools
   - Create your infrastructure (10-15 minutes)
   - Build and upload your app
   - Deploy your app to Kubernetes
   - Give you the URL to access your app

## How to Deploy (Step by Step for Learning)

### Step 1: Initialize Terraform
```bash
cd terraform
terraform init
```
This downloads the AWS plugin for Terraform.

### Step 2: Plan the Deployment
```bash
terraform plan
```
This shows you what will be created (without actually creating it).

### Step 3: Create the Infrastructure
```bash
terraform apply
```
This actually creates everything in AWS. Takes about 10-15 minutes.

### Step 4: Connect to Your Cluster
```bash
aws eks --region us-east-1 update-kubeconfig --name kudos-app
kubectl get nodes
```
This connects your computer to the new Kubernetes cluster.

### Step 5: Build and Upload Your App
```bash
# Get the registry URL
ECR_REPO=$(terraform output -raw ecr_repository_url)

# Login to the registry
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO

# Build your app
docker build -t kudos-app .

# Tag and upload
docker tag kudos-app:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

### Step 6: Deploy to Kubernetes
Create a file called `app.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kudos-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: kudos-app
  template:
    metadata:
      labels:
        app: kudos-app
    spec:
      containers:
      - name: kudos-app
        image: YOUR_ECR_URL:latest  # Replace with actual URL
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: kudos-app-service
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: kudos-app
```

Deploy it:
```bash
kubectl apply -f app.yaml
```

Get your app URL:
```bash
kubectl get svc kudos-app-service
```

## Understanding the Costs

This will cost approximately **$100-150 per month** while running:
- EKS Cluster: ~$75/month
- 2 t3.medium servers: ~$60/month
- Network components: ~$15/month

**Important:** Always run `terraform destroy` when you're done to avoid charges!

## Common Commands

```bash
# See what's running
kubectl get pods

# See your app logs
kubectl logs -l app=kudos-app

# Scale your app (run more copies)
kubectl scale deployment kudos-app --replicas=3

# Delete everything
cd terraform
terraform destroy
```

## Teaching Tips

When explaining this to non-IT people:

1. **Start with analogies:**
   - VPC = Your own private neighborhood
   - Subnets = Streets in that neighborhood
   - EKS = A property manager for apartment buildings
   - Pods = Individual apartments where apps live

2. **Focus on the "what" before the "how":**
   - Explain what each component does
   - Then show how Terraform creates it

3. **Use the visual AWS console:**
   - After deployment, log into AWS console
   - Show them the created resources visually
   - This helps connect the code to actual infrastructure

4. **Emphasize the benefits:**
   - No server management needed
   - Automatic scaling
   - High availability
   - Professional-grade security

## Troubleshooting

**"terraform init" fails:**
- Make sure you have AWS credentials configured: `aws configure`

**"terraform apply" fails:**
- Check your AWS permissions
- Make sure you're not hitting AWS limits

**App won't start:**
- Check Docker image builds locally: `docker build -t kudos-app .`
- Check Kubernetes pod status: `kubectl describe pod <pod-name>`

**Can't access app:**
- Load balancer takes 2-3 minutes to provision
- Check service status: `kubectl get svc`

## What Happens When You Deploy

1. **Terraform reads your .tf files** and creates a plan
2. **AWS receives the requests** and starts creating resources
3. **A VPC is created** with public and private networks
4. **An EKS cluster starts up** (this takes the longest time)
5. **Worker nodes join the cluster** (your actual computers)
6. **ECR repository is created** for your images
7. **Docker builds your app** into a container image
8. **Image is uploaded** to your private registry
9. **Kubernetes deploys your app** across multiple nodes
10. **Load balancer creates** a public URL for your app

The whole process takes 15-20 minutes, but then you have professional-grade infrastructure running your simple React app!

## Clean Up

**Always remember to clean up when done:**
```bash
cd terraform
terraform destroy
```

This prevents unexpected AWS charges.