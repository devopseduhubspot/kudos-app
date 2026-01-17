#!/bin/bash

# Workflow 2: Deploy Kudos App to EKS
# This script deploys your React application to the existing EKS cluster
# Run this AFTER you have created the infrastructure with create-infrastructure.sh

set -e

echo "🚀 Kudos App Deployment Workflow"
echo "==============================="
echo "This will:"
echo "- Build your React app into a container"
echo "- Upload it to your private registry"
echo "- Deploy it to Kubernetes"
echo "- Create a public URL for access"
echo ""

# Check prerequisites
echo "🔍 Step 1: Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not installed."
    echo "   Install from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is required but not installed."
    echo "   Install from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

echo "✅ All tools are installed"

# Check if infrastructure exists
echo "🏗️  Step 2: Checking infrastructure..."
cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo "❌ No infrastructure found!"
    echo "   Please run: ./create-infrastructure.sh first"
    exit 1
fi

# Get infrastructure details
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
ECR_REPO_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")

if [ -z "$CLUSTER_NAME" ] || [ -z "$ECR_REPO_URL" ]; then
    echo "❌ Infrastructure not ready!"
    echo "   Please run: ./create-infrastructure.sh first"
    exit 1
fi

echo "✅ Infrastructure found:"
echo "   Cluster: $CLUSTER_NAME"
echo "   Registry: $ECR_REPO_URL"

# Check cluster connectivity
echo "🔗 Checking cluster connection..."
if ! kubectl get nodes &> /dev/null; then
    echo "⚠️  Configuring cluster access..."
    aws eks --region us-east-1 update-kubeconfig --name $CLUSTER_NAME
fi

NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "✅ Connected to cluster with $NODE_COUNT worker nodes"

# Build application
echo ""
echo "🏗️  Step 3: Building your application..."
cd ..

echo "   Building Docker image..."
docker build -t kudos-app:latest .

echo "   Tagging image for ECR..."
docker tag kudos-app:latest $ECR_REPO_URL:latest

# Push to ECR
echo ""
echo "📤 Step 4: Uploading to container registry..."
echo "   Logging into ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO_URL

echo "   Pushing image..."
docker push $ECR_REPO_URL:latest

echo "✅ Image uploaded successfully"

# Deploy to Kubernetes
echo ""
echo "🚀 Step 5: Deploying to Kubernetes..."

# Create deployment manifest
echo "   Creating Kubernetes deployment..."
cat > kudos-deployment.yaml << EOF
# Deployment: Tells Kubernetes how to run your app
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kudos-app
  labels:
    app: kudos-app
spec:
  replicas: 2  # Run 2 copies of your app for reliability
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
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
# Service: Makes your app accessible within the cluster
apiVersion: v1
kind: Service
metadata:
  name: kudos-app-service
  labels:
    app: kudos-app
spec:
  type: LoadBalancer  # This creates a public URL
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: kudos-app
EOF

echo "   Applying deployment to cluster..."
kubectl apply -f kudos-deployment.yaml

echo "   Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/kudos-app

# Get public URL
echo ""
echo "🌐 Step 6: Getting your app's public URL..."
echo "   Waiting for load balancer to be ready..."
echo "   (This can take 2-3 minutes...)"

# Wait for external IP
for i in {1..20}; do
    EXTERNAL_URL=$(kubectl get svc kudos-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ ! -z "$EXTERNAL_URL" ]; then
        break
    fi
    echo "   Still setting up load balancer... (attempt $i/20)"
    sleep 15
done

echo ""
echo "🎉 Deployment Complete!"
echo "================================"

if [ ! -z "$EXTERNAL_URL" ]; then
    echo "🌐 Your app is live at: http://$EXTERNAL_URL"
    echo ""
    echo "🔗 Direct link: http://$EXTERNAL_URL"
else
    echo "⏳ Load balancer still setting up. Get URL with:"
    echo "   kubectl get svc kudos-app-service"
    echo ""
    echo "   Look for the 'EXTERNAL-IP' column"
fi

echo ""
echo "📊 Application Status:"
kubectl get pods -l app=kudos-app
echo ""

echo "📝 Useful Commands:"
echo "   kubectl get pods              # See your app instances"
echo "   kubectl get svc               # See services and URLs"
echo "   kubectl logs -l app=kudos-app # See app logs"
echo "   kubectl describe pod <name>   # Debug specific pod"
echo ""

echo "🔄 To update your app:"
echo "   1. Make changes to your code"
echo "   2. Run this script again"
echo "   3. Kubernetes will automatically update"
echo ""

echo "🗑️  To clean up:"
echo "   kubectl delete -f kudos-deployment.yaml  # Remove app only"
echo "   ./destroy-infrastructure.sh              # Remove everything"