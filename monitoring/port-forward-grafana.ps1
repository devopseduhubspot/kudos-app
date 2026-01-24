# =============================================================================
# Grafana Port Forward Script (PowerShell)
# =============================================================================
# This script creates a port forward to the Grafana service running in your
# Kubernetes cluster, making it accessible via http://localhost:3000
# =============================================================================

param(
    [string]$Namespace = "monitoring",
    [string]$ReleaseName = "kube-prometheus-stack",
    [int]$LocalPort = 3000
)

# Set error handling
$ErrorActionPreference = "Stop"

# Utility functions
function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "❌ ERROR: $Message" -ForegroundColor Red
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

# =============================================================================
# 1. Prerequisites Check
# =============================================================================
Write-Header "🔍 Grafana Port Forward - Prerequisites Check"

# Check if kubectl is available
try {
    kubectl version --client | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "kubectl command failed" }
    Write-Success "kubectl is available"
} catch {
    Write-Error-Custom "kubectl is not installed or not in PATH"
    exit 1
}

# Check if we can connect to the cluster
try {
    kubectl cluster-info | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "cluster-info failed" }
    Write-Success "Connected to Kubernetes cluster"
} catch {
    Write-Error-Custom "Cannot connect to Kubernetes cluster"
    Write-Status "Please check your kubectl configuration"
    exit 1
}

# =============================================================================
# 2. Check Monitoring Stack
# =============================================================================
Write-Header "📊 Checking monitoring stack..."

# Check if namespace exists
try {
    kubectl get namespace $Namespace | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "namespace not found" }
    Write-Success "Found namespace: $Namespace"
} catch {
    Write-Error-Custom "Namespace '$Namespace' not found"
    Write-Status "Make sure the monitoring stack is installed first"
    Write-Status "Run: .\install-monitoring.ps1"
    exit 1
}

# Check if Grafana service exists
$ServiceName = "$ReleaseName-grafana"
try {
    kubectl get service $ServiceName -n $Namespace | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "service not found" }
    Write-Success "Found Grafana service: $ServiceName"
} catch {
    Write-Error-Custom "Grafana service '$ServiceName' not found in namespace '$Namespace'"
    Write-Status "Available services in $Namespace namespace:"
    kubectl get services -n $Namespace
    exit 1
}

# Check if Grafana pods are running
try {
    $pods = kubectl get pods -n $Namespace -l "app.kubernetes.io/name=grafana" --no-headers
    if ($LASTEXITCODE -ne 0 -or -not $pods) {
        Write-Error-Custom "No Grafana pods found"
        exit 1
    }
    
    $runningPods = ($pods | Where-Object { $_ -match "Running" }).Count
    $totalPods = ($pods -split "`n").Count
    
    if ($runningPods -eq $totalPods) {
        Write-Success "Grafana pods are running ($runningPods/$totalPods)"
    } else {
        Write-Error-Custom "Some Grafana pods are not running ($runningPods/$totalPods)"
        Write-Status "Pod status:"
        kubectl get pods -n $Namespace -l "app.kubernetes.io/name=grafana"
        exit 1
    }
} catch {
    Write-Error-Custom "Could not check Grafana pod status"
    exit 1
}

# =============================================================================
# 3. Retrieve Grafana Admin Password
# =============================================================================
Write-Header "🔐 Retrieving Grafana admin password..."

$SecretName = "$ReleaseName-grafana"
try {
    # Get the admin password from the secret
    $passwordBase64 = kubectl get secret $SecretName -n $Namespace -o jsonpath="{.data.admin-password}"
    if ($LASTEXITCODE -ne 0 -or -not $passwordBase64) {
        throw "Could not retrieve password from secret"
    }
    
    # Decode the base64 password
    $adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($passwordBase64))
    Write-Success "Retrieved admin password from secret"
    
} catch {
    Write-Error-Custom "Could not retrieve Grafana admin password"
    Write-Status "Available secrets in $Namespace namespace:"
    kubectl get secrets -n $Namespace
    exit 1
}

# =============================================================================
# 4. Check if Port is Available
# =============================================================================
Write-Status "🌐 Checking if port $LocalPort is available..."

try {
    $tcpListener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $LocalPort)
    $tcpListener.Start()
    $tcpListener.Stop()
    Write-Success "Port $LocalPort is available"
} catch {
    Write-Error-Custom "Port $LocalPort is already in use"
    Write-Status "Please choose a different port with: .\port-forward-grafana.ps1 -LocalPort <port>"
    exit 1
}

# =============================================================================
# 5. Display Access Information
# =============================================================================
Write-Header "🎯 Grafana Access Information"

Write-Host ""
Write-Host "📊 Grafana will be accessible at: http://localhost:$LocalPort" -ForegroundColor Yellow
Write-Host "👤 Username: admin" -ForegroundColor Yellow
Write-Host "🔐 Password: $adminPassword" -ForegroundColor Yellow
Write-Host ""

Write-Status "The password has been copied to your clipboard (if supported)"
try {
    $adminPassword | Set-Clipboard
} catch {
    # Clipboard may not be available in some environments
}

Write-Status "Press Ctrl+C to stop the port forward when you're done"
Write-Host ""

# =============================================================================
# 6. Start Port Forward
# =============================================================================
Write-Header "🚀 Starting port forward..."

Write-Status "Starting kubectl port-forward..."
Write-Status "Command: kubectl port-forward -n $Namespace service/$ServiceName ${LocalPort}:80"

try {
    # Start the port forward (this will block until stopped)
    kubectl port-forward -n $Namespace service/$ServiceName "${LocalPort}:80"
} catch {
    Write-Error-Custom "Port forward failed: $_"
    exit 1
} finally {
    Write-Status "Port forward stopped"
}