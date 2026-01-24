# =============================================================================
# Kubernetes Monitoring Installation Script (PowerShell)
# =============================================================================
# This script installs Prometheus and Grafana monitoring stack on your
# Kubernetes cluster using Helm charts.
#
# What this script does:
# 1. Checks prerequisites (kubectl, helm, cluster connectivity)
# 2. Verifies EBS CSI driver setup
# 3. Creates monitoring namespace
# 4. Adds Prometheus Community Helm repository
# 5. Installs kube-prometheus-stack with custom values
# 6. Provides access instructions
# =============================================================================

param(
    [string]$Namespace = "monitoring",
    [string]$ReleaseName = "kube-prometheus-stack",
    [string]$HelmTimeout = "10m",
    [switch]$SkipEbsCheck = $false
)

# Set error handling
$ErrorActionPreference = "Stop"

# Colors for output (PowerShell equivalent)
function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "❌ ERROR: $Message" -ForegroundColor Red
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠️  WARNING: $Message" -ForegroundColor Yellow
}

function Write-Status {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n=============================================================================" -ForegroundColor Blue
    Write-Host "$Message" -ForegroundColor Blue
    Write-Host "=============================================================================" -ForegroundColor Blue
}

function Exit-WithError {
    param([string]$Message)
    Write-Error-Custom $Message
    exit 1
}

# =============================================================================
# 1. Prerequisites Check
# =============================================================================
Write-Header "📋 Checking prerequisites..."

# Check if kubectl is installed and working
try {
    $kubectlVersion = kubectl version --client --output=yaml 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) { throw "kubectl command failed" }
    Write-Success "kubectl is available"
} catch {
    Exit-WithError "kubectl is not installed or not in PATH"
}

# Check if helm is installed
try {
    $helmVersion = helm version --short 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) { throw "helm command failed" }
    Write-Success "helm is available"
} catch {
    Exit-WithError "Helm is not installed or not in PATH. Please install Helm: https://helm.sh/docs/intro/install/"
}

# Check if we can connect to the cluster
try {
    kubectl cluster-info | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "cluster-info failed" }
    Write-Success "Connected to Kubernetes cluster"
} catch {
    Exit-WithError "Cannot connect to Kubernetes cluster. Please check your kubectl configuration"
}

# Check if EBS CSI driver is available (unless skipped)
if (-not $SkipEbsCheck) {
    Write-Status "🔍 Checking EBS CSI driver..."
    try {
        $EbsCsiPods = kubectl get pods -n kube-system -l app=ebs-csi-controller --no-headers 2>$null
        if ($LASTEXITCODE -ne 0) { $EbsCsiCount = 0 } 
        else { $EbsCsiCount = ($EbsCsiPods | Measure-Object -Line).Lines }
        
        if ($EbsCsiCount -lt 1) {
            Write-Warning-Custom "EBS CSI driver not found. Storage provisioning may fail."
            Write-Status "The workflow should have set this up automatically."
            
            # Check if we're running in GitHub Actions
            if ($env:GITHUB_ACTIONS) {
                Exit-WithError "EBS CSI driver should have been set up by the workflow. Please check the workflow logs for EBS CSI driver setup errors."
            } else {
                Write-Status "To set up EBS CSI driver automatically, run:"
                Write-Status "  .\setup-ebs-csi-driver.ps1"
                Write-Host ""
                $continue = Read-Host "Do you want to continue without EBS CSI driver? (y/N)"
                if ($continue -notmatch '^[Yy]$') {
                    Write-Status "Exiting. Please set up EBS CSI driver first."
                    exit 1
                }
            }
            
            # Check storage class
            try {
                kubectl get storageclass gp2 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "gp2 not found" }
            } catch {
                Exit-WithError "Storage class 'gp2' not found. Persistent volumes will not work without a storage class. Please check your EBS CSI driver installation."
            }
        } else {
            Write-Success "EBS CSI driver found ($EbsCsiCount controller pods)"
        }
    } catch {
        Write-Warning-Custom "Could not check EBS CSI driver status: $_"
    }
} else {
    Write-Status "🔍 Skipping EBS CSI driver check (--SkipEbsCheck specified)"
}

Write-Success "All prerequisites met!"

# =============================================================================
# 2. Create Monitoring Namespace
# =============================================================================
Write-Header "🏗️  Creating monitoring namespace..."

try {
    kubectl get namespace $Namespace | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Warning-Custom "Namespace '$Namespace' already exists"
    }
} catch {
    kubectl create namespace $Namespace
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Created namespace '$Namespace'"
    } else {
        Exit-WithError "Failed to create namespace '$Namespace'"
    }
}

# =============================================================================
# 3. Add Prometheus Community Helm Repository
# =============================================================================
Write-Header "📦 Adding Prometheus Community Helm repository..."

try {
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Helm repository added and updated!"
    } else {
        throw "Helm repo operations failed"
    }
} catch {
    Exit-WithError "Failed to add or update Helm repository: $_"
}

# =============================================================================
# 4. Install Monitoring Stack
# =============================================================================
Write-Header "🚀 Installing Prometheus and Grafana monitoring stack..."

Write-Status "📊 Installing kube-prometheus-stack..."
Write-Status "📍 Namespace: $Namespace"
Write-Status "🏷️  Release name: $ReleaseName"
Write-Status "⏱️  Timeout: $HelmTimeout"
Write-Status "📁 Values file: values.yaml"

# Check if values.yaml exists
if (-not (Test-Path "values.yaml")) {
    Exit-WithError "values.yaml file not found in current directory. Please run this script from the monitoring directory."
}

try {
    # Install the helm chart
    helm upgrade --install $ReleaseName prometheus-community/kube-prometheus-stack `
        --namespace $Namespace `
        --create-namespace `
        --values values.yaml `
        --timeout $HelmTimeout `
        --wait
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Monitoring stack installed successfully!"
    } else {
        throw "Helm install failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Error-Custom "Failed to install monitoring stack: $_"
    Write-Status "🔍 You can check the installation status with:"
    Write-Status "   helm list -n $Namespace"
    Write-Status "   kubectl get pods -n $Namespace"
    exit 1
}

# =============================================================================
# 5. Verify Installation
# =============================================================================
Write-Header "✅ Verifying installation..."

Write-Status "📊 Checking Helm release status..."
try {
    helm list -n $Namespace
    Write-Success "Helm release is listed"
} catch {
    Write-Warning-Custom "Could not list Helm releases"
}

Write-Status "🔍 Checking pod status..."
try {
    kubectl get pods -n $Namespace
    Write-Success "Pods are listed above"
} catch {
    Write-Warning-Custom "Could not list pods"
}

# Wait for pods to be ready
Write-Status "⏳ Waiting for pods to be ready (this may take a few minutes)..."
try {
    # Wait for key deployments to be ready
    $deployments = @(
        "kube-prometheus-stack-operator",
        "kube-prometheus-stack-grafana"
    )
    
    foreach ($deployment in $deployments) {
        Write-Status "Waiting for deployment: $deployment"
        kubectl rollout status deployment/$deployment -n $Namespace --timeout=300s
        if ($LASTEXITCODE -ne 0) {
            Write-Warning-Custom "Deployment $deployment may not be ready"
        }
    }
    
    # Wait for StatefulSets
    $statefulsets = @(
        "prometheus-kube-prometheus-stack",
        "alertmanager-kube-prometheus-stack"
    )
    
    foreach ($sts in $statefulsets) {
        Write-Status "Waiting for StatefulSet: $sts"
        kubectl rollout status statefulset/$sts -n $Namespace --timeout=300s
        if ($LASTEXITCODE -ne 0) {
            Write-Warning-Custom "StatefulSet $sts may not be ready"
        }
    }
    
    Write-Success "All components appear to be deployed!"
} catch {
    Write-Warning-Custom "Some components may still be starting up: $_"
}

# =============================================================================
# 6. Display Access Instructions
# =============================================================================
Write-Header "📊 Access Your Monitoring Stack"

Write-Status "🎉 Installation completed successfully!"
Write-Host ""

Write-Host "📈 Grafana Dashboard (Recommended)" -ForegroundColor Cyan
Write-Status "1. Get the auto-generated admin password:"
Write-Host "   kubectl get secret $ReleaseName-grafana -n $Namespace -o jsonpath=`"{.data.admin-password}`" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(`$_)) }"

Write-Status "2. Port-forward to access Grafana:"
Write-Host "   kubectl port-forward -n $Namespace svc/$ReleaseName-grafana 3000:80"

Write-Status "3. Visit: http://localhost:3000"
Write-Status "   Username: admin"
Write-Status "   Password: Use the password from step 1"
Write-Host ""

Write-Host "🔍 Prometheus Query Interface" -ForegroundColor Cyan
Write-Status "Port-forward Prometheus:"
Write-Host "   kubectl port-forward -n $Namespace svc/$ReleaseName-prometheus 9090:9090"
Write-Status "Visit: http://localhost:9090"
Write-Host ""

Write-Host "🚨 AlertManager Interface" -ForegroundColor Cyan
Write-Status "Port-forward AlertManager:"
Write-Host "   kubectl port-forward -n $Namespace svc/$ReleaseName-alertmanager 9093:9093"
Write-Status "Visit: http://localhost:9093"
Write-Host ""

Write-Host "📋 Quick Commands" -ForegroundColor Cyan
Write-Status "Check all pods: kubectl get pods -n $Namespace"
Write-Status "Check services: kubectl get svc -n $Namespace"
Write-Status "Check PVCs: kubectl get pvc -n $Namespace"
Write-Host ""

Write-Host "🎯 Next Steps:" -ForegroundColor Green
Write-Status "1. Access Grafana and explore the pre-built Kubernetes dashboards"
Write-Status "2. Check out the 'Kubernetes' folder for cluster metrics"
Write-Status "3. Monitor your Kudos application metrics"
Write-Status "4. Set up custom alerts based on your requirements"

Write-Header "🎉 Monitoring Stack Installation Complete!"
Write-Success "Happy monitoring! 🚀"
Write-Host ""