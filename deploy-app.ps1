# PowerShell Script: Deploy Kudos App to EKS
# This script deploys your React application to the existing EKS cluster
# Run this AFTER you have created the infrastructure with create-infrastructure.ps1

Write-Host "🚀 Kudos App Deployment Workflow" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green
Write-Host "This will:"
Write-Host "- Build your React app into a container"
Write-Host "- Upload it to your private registry"
Write-Host "- Deploy it to Kubernetes"
Write-Host "- Create a public URL for access"
Write-Host ""

# Check prerequisites
Write-Host "🔍 Step 1: Checking prerequisites..." -ForegroundColor Cyan

# Check Docker
if (!(Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker is required but not installed." -ForegroundColor Red
    Write-Host "   Install from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Check kubectl
if (!(Get-Command "kubectl" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ kubectl is required but not installed." -ForegroundColor Red
    Write-Host "   Install from: https://kubernetes.io/docs/tasks/tools/" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ All tools are installed" -ForegroundColor Green

# Check if infrastructure exists
Write-Host "🏗️  Step 2: Checking infrastructure..." -ForegroundColor Cyan
Set-Location terraform

if (!(Test-Path "terraform.tfstate")) {
    Write-Host "❌ No infrastructure found!" -ForegroundColor Red
    Write-Host "   Please run: .\create-infrastructure.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Get infrastructure details
try {
    $clusterName = terraform output -raw cluster_name 2>$null
    $ecrRepoUrl = terraform output -raw ecr_repository_url 2>$null
    
    if ([string]::IsNullOrEmpty($clusterName) -or [string]::IsNullOrEmpty($ecrRepoUrl)) {
        throw "Infrastructure outputs not available"
    }
    
    Write-Host "✅ Infrastructure found:" -ForegroundColor Green
    Write-Host "   Cluster: $clusterName"
    Write-Host "   Registry: $ecrRepoUrl"
} catch {
    Write-Host "❌ Infrastructure not ready!" -ForegroundColor Red
    Write-Host "   Please run: .\create-infrastructure.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Check cluster connectivity
Write-Host "🔗 Checking cluster connection..." -ForegroundColor Cyan
$nodeCheck = kubectl get nodes 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Configuring cluster access..." -ForegroundColor Yellow
    aws eks --region us-east-1 update-kubeconfig --name $clusterName
}

$nodeCount = (kubectl get nodes --no-headers | Measure-Object).Count
Write-Host "✅ Connected to cluster with $nodeCount worker nodes" -ForegroundColor Green

# Build application
Write-Host ""
Write-Host "🏗️  Step 3: Building your application..." -ForegroundColor Cyan
Set-Location ..

Write-Host "   Building Docker image..." -ForegroundColor White
docker build -t kudos-app:latest .

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "   Tagging image for ECR..." -ForegroundColor White
docker tag kudos-app:latest "$($ecrRepoUrl):latest"

# Push to ECR
Write-Host ""
Write-Host "📤 Step 4: Uploading to container registry..." -ForegroundColor Cyan
Write-Host "   Logging into ECR..." -ForegroundColor White

$loginCmd = aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ecrRepoUrl
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ECR login failed!" -ForegroundColor Red
    exit 1
}

Write-Host "   Pushing image..." -ForegroundColor White
docker push "$($ecrRepoUrl):latest"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Image push failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Image uploaded successfully" -ForegroundColor Green

# Deploy to Kubernetes
Write-Host ""
Write-Host "🚀 Step 5: Deploying to Kubernetes..." -ForegroundColor Cyan

# Create deployment manifest
Write-Host "   Creating Kubernetes deployment..." -ForegroundColor White
$deploymentYaml = @"
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
        image: $($ecrRepoUrl):latest
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
"@

$deploymentYaml | Out-File -FilePath "kudos-deployment.yaml" -Encoding UTF8

Write-Host "   Applying deployment to cluster..." -ForegroundColor White
kubectl apply -f kudos-deployment.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "   Waiting for deployment to be ready..." -ForegroundColor White
kubectl wait --for=condition=available --timeout=300s deployment/kudos-app

# Get public URL
Write-Host ""
Write-Host "🌐 Step 6: Getting your app's public URL..." -ForegroundColor Cyan
Write-Host "   Waiting for load balancer to be ready..." -ForegroundColor White
Write-Host "   (This can take 2-3 minutes...)" -ForegroundColor Yellow

# Wait for external IP
$externalUrl = ""
for ($i = 1; $i -le 20; $i++) {
    $externalUrl = kubectl get svc kudos-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
    if (![string]::IsNullOrEmpty($externalUrl)) {
        break
    }
    Write-Host "   Still setting up load balancer... (attempt $i/20)" -ForegroundColor White
    Start-Sleep -Seconds 15
}

Write-Host ""
Write-Host "🎉 Deployment Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

if (![string]::IsNullOrEmpty($externalUrl)) {
    Write-Host "🌐 Your app is live at: http://$externalUrl" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔗 Direct link: http://$externalUrl" -ForegroundColor Cyan
} else {
    Write-Host "⏳ Load balancer still setting up. Get URL with:" -ForegroundColor Yellow
    Write-Host "   kubectl get svc kudos-app-service" -ForegroundColor White
    Write-Host ""
    Write-Host "   Look for the 'EXTERNAL-IP' column" -ForegroundColor White
}

Write-Host ""
Write-Host "📊 Application Status:" -ForegroundColor Cyan
kubectl get pods -l app=kudos-app
Write-Host ""

Write-Host "📝 Useful Commands:" -ForegroundColor Cyan
Write-Host "   kubectl get pods              # See your app instances"
Write-Host "   kubectl get svc               # See services and URLs"
Write-Host "   kubectl logs -l app=kudos-app # See app logs"
Write-Host "   kubectl describe pod <name>   # Debug specific pod"
Write-Host ""

Write-Host "🔄 To update your app:" -ForegroundColor Cyan
Write-Host "   1. Make changes to your code"
Write-Host "   2. Run this script again"
Write-Host "   3. Kubernetes will automatically update"
Write-Host ""

Write-Host "🗑️  To clean up:" -ForegroundColor Yellow
Write-Host "   kubectl delete -f kudos-deployment.yaml  # Remove app only"
Write-Host "   .\destroy-infrastructure.ps1              # Remove everything"