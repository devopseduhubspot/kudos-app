#!/bin/bash

# Simple deployment script for Kudos App
# This script does everything step by step with clear explanations

echo "🚀 Welcome! Let's deploy your Kudos app to AWS!"
echo "This will create a Kubernetes cluster and deploy your app."
echo ""

# Check if required tools are installed
echo "🔍 Checking if you have the required tools..."

if ! command -v aws &> /dev/null; then
    echo "❌ You need AWS CLI. Please install it first."
    echo "   Visit: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ You need Terraform. Please install it first."
    echo "   Visit: https://www.terraform.io/downloads.html"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ You need Docker. Please install it first."
    echo "   Visit: https://www.docker.com/products/docker-desktop"
    exit 1
fi

echo "✅ Great! All required tools are installed."
echo ""

# Step 1: Set up Terraform
echo "📦 Step 1: Setting up Terraform..."
cd terraform

# Initialize Terraform (download required plugins)
echo "   Downloading Terraform plugins..."
terraform init

echo "   Creating deployment plan..."
terraform plan -out=deployment.plan

echo "   Ready to deploy!"
echo ""

# Ask user if they want to continue
read -p "🤔 Do you want to continue with the deployment? This will create resources in AWS. (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "👋 Okay, exiting. Run this script again when you're ready!"
    exit 0
fi

# Step 2: Deploy the infrastructure
echo ""
echo "🏗️  Step 2: Creating your Kubernetes cluster..."
echo "   This takes about 10-15 minutes. Perfect time for a coffee! ☕"

terraform apply deployment.plan

# Get the important information
CLUSTER_NAME=$(terraform output -raw cluster_name)
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)

echo ""
echo "✅ Step 2 complete! Your cluster is ready."
echo "   Cluster name: $CLUSTER_NAME"
echo "   Image repository: $ECR_REPO_URL"

# Step 3: Connect to the cluster
echo ""
echo "🔧 Step 3: Connecting to your cluster..."
aws eks --region us-east-1 update-kubeconfig --name $CLUSTER_NAME

echo "   Testing connection..."
kubectl get nodes

echo "✅ Step 3 complete! You're connected to your cluster."

# Step 4: Build and upload your app
echo ""
echo "🐳 Step 4: Building your app..."
cd ..

# Login to your container registry
echo "   Logging into your private image repository..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO_URL

# Build your app
echo "   Building your app image..."
docker build -t kudos-app .

# Tag it for your repository
docker tag kudos-app:latest $ECR_REPO_URL:latest

# Upload it
echo "   Uploading your app to AWS..."
docker push $ECR_REPO_URL:latest

echo "✅ Step 4 complete! Your app is uploaded."

# Step 5: Deploy the app to Kubernetes
echo ""
echo "🚀 Step 5: Deploying your app to Kubernetes..."

# Create a simple deployment file
cat > app-deployment.yaml << EOF
# This tells Kubernetes how to run your app
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kudos-app
spec:
  replicas: 2  # Run 2 copies of your app
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
        image: $ECR_REPO_URL:latest
        ports:
        - containerPort: 80
---
# This makes your app accessible
apiVersion: v1
kind: Service
metadata:
  name: kudos-app-service
spec:
  type: LoadBalancer  # This creates a public URL
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: kudos-app
EOF

# Deploy it
kubectl apply -f app-deployment.yaml

echo "   Waiting for your app to start..."
kubectl wait --for=condition=available --timeout=300s deployment/kudos-app

echo "   Getting your app's public URL..."
echo "   This might take a few minutes..."

# Wait for load balancer to get an external IP
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl get svc kudos-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$EXTERNAL_IP" ]; then
        break
    fi
    echo "   Still setting up... (attempt $i/30)"
    sleep 20
done

echo ""
echo "🎉 Deployment Complete!"
echo ""
if [ ! -z "$EXTERNAL_IP" ]; then
    echo "🌐 Your app is live at: http://$EXTERNAL_IP"
else
    echo "⏳ Your app is starting up. Get the URL with:"
    echo "   kubectl get svc kudos-app-service"
fi
echo ""
echo "📊 Useful commands:"
echo "   See your app: kubectl get pods"
echo "   See app logs: kubectl logs -l app=kudos-app"
echo "   Delete everything: cd terraform && terraform destroy"
echo ""
echo "💰 Remember: This costs money while running. Destroy when not needed!"