# =============================================================================
# Monitoring Stack Uninstall Script (PowerShell)
# =============================================================================
# This script removes the Prometheus and Grafana monitoring stack from your
# Kubernetes cluster.
#
# What this script does:
# 1. Checks prerequisites
# 2. Removes Helm release
# 3. Deletes persistent volumes (optional)
# 4. Cleans up namespace (optional)
# =============================================================================

param(
    [string]$Namespace = "monitoring",
    [string]$ReleaseName = "kube-prometheus-stack",
    [switch]$DeletePVCs = $false,
    [switch]$DeleteNamespace = $false,
    [switch]$Force = $false
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

# =============================================================================
# 1. Prerequisites Check
# =============================================================================
Write-Header "🗑️  Monitoring Stack Uninstall"

# Check if kubectl is available
try {
    kubectl version --client | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "kubectl command failed" }
    Write-Success "kubectl is available"
} catch {
    Write-Error-Custom "kubectl is not installed or not in PATH"
    exit 1
}

# Check if helm is available
try {
    helm version --short | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "helm command failed" }
    Write-Success "helm is available"
} catch {
    Write-Error-Custom "Helm is not installed or not in PATH"
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
# 2. Confirmation
# =============================================================================
if (-not $Force) {
    Write-Warning-Custom "This will remove the monitoring stack from your cluster!"
    Write-Status "Namespace: $Namespace"
    Write-Status "Release: $ReleaseName"
    Write-Status "Delete PVCs: $DeletePVCs"
    Write-Status "Delete Namespace: $DeleteNamespace"
    Write-Host ""
    
    $confirm = Read-Host "Are you sure you want to continue? (y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Status "Operation cancelled by user"
        exit 0
    }
}

# =============================================================================
# 3. Check if Installation Exists
# =============================================================================
Write-Header "🔍 Checking current installation..."

# Check if namespace exists
try {
    kubectl get namespace $Namespace | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning-Custom "Namespace '$Namespace' not found"
        Write-Status "Nothing to uninstall"
        exit 0
    }
    Write-Success "Found namespace: $Namespace"
} catch {
    Write-Warning-Custom "Could not check namespace"
}

# Check if Helm release exists
try {
    $releaseInfo = helm list -n $Namespace -f $ReleaseName --output json | ConvertFrom-Json
    if (-not $releaseInfo -or $releaseInfo.Count -eq 0) {
        Write-Warning-Custom "Helm release '$ReleaseName' not found in namespace '$Namespace'"
        Write-Status "Checking what's in the namespace:"
        kubectl get all -n $Namespace
    } else {
        Write-Success "Found Helm release: $ReleaseName"
        Write-Status "Release info:"
        helm list -n $Namespace -f $ReleaseName
    }
} catch {
    Write-Warning-Custom "Could not check Helm release: $_"
}

# =============================================================================
# 4. Remove Helm Release
# =============================================================================
Write-Header "🗑️  Removing Helm release..."

try {
    Write-Status "Uninstalling Helm release: $ReleaseName"
    helm uninstall $ReleaseName -n $Namespace
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Helm release removed successfully"
    } else {
        Write-Warning-Custom "Helm uninstall may have failed, but continuing..."
    }
} catch {
    Write-Warning-Custom "Error during Helm uninstall: $_"
    Write-Status "Continuing with cleanup..."
}

# Wait for pods to terminate
Write-Status "⏳ Waiting for pods to terminate..."
try {
    $maxWait = 60 # seconds
    $waited = 0
    
    while ($waited -lt $maxWait) {
        $pods = kubectl get pods -n $Namespace --no-headers 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $pods) {
            Write-Success "All pods have been terminated"
            break
        }
        
        Start-Sleep -Seconds 5
        $waited += 5
        Write-Status "Still waiting for pods to terminate... ($waited/$maxWait seconds)"
    }
    
    if ($waited -ge $maxWait) {
        Write-Warning-Custom "Some pods may still be terminating"
        kubectl get pods -n $Namespace
    }
} catch {
    Write-Warning-Custom "Could not check pod status: $_"
}

# =============================================================================
# 5. Delete Persistent Volume Claims (Optional)
# =============================================================================
if ($DeletePVCs) {
    Write-Header "🗄️  Removing Persistent Volume Claims..."
    
    try {
        $pvcs = kubectl get pvc -n $Namespace --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $pvcs) {
            Write-Status "Found PVCs in namespace $Namespace:"
            kubectl get pvc -n $Namespace
            
            Write-Warning-Custom "Deleting PVCs will permanently delete all monitoring data!"
            if (-not $Force) {
                $confirmPVC = Read-Host "Are you sure you want to delete PVCs? (y/N)"
                if ($confirmPVC -notmatch '^[Yy]$') {
                    Write-Status "Skipping PVC deletion"
                } else {
                    kubectl delete pvc --all -n $Namespace
                    Write-Success "PVCs deleted"
                }
            } else {
                kubectl delete pvc --all -n $Namespace
                Write-Success "PVCs deleted"
            }
        } else {
            Write-Status "No PVCs found in namespace $Namespace"
        }
    } catch {
        Write-Warning-Custom "Error handling PVCs: $_"
    }
} else {
    Write-Status "🗄️  Skipping PVC deletion (use -DeletePVCs to remove data)"
    try {
        $pvcs = kubectl get pvc -n $Namespace --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $pvcs) {
            Write-Status "Persistent volumes with data are still present:"
            kubectl get pvc -n $Namespace
        }
    } catch {
        # Ignore errors when checking PVCs
    }
}

# =============================================================================
# 6. Delete Namespace (Optional)
# =============================================================================
if ($DeleteNamespace) {
    Write-Header "🗑️  Removing namespace..."
    
    Write-Warning-Custom "Deleting the namespace will remove everything in it!"
    if (-not $Force) {
        $confirmNS = Read-Host "Are you sure you want to delete namespace '$Namespace'? (y/N)"
        if ($confirmNS -notmatch '^[Yy]$') {
            Write-Status "Keeping namespace $Namespace"
        } else {
            kubectl delete namespace $Namespace
            Write-Success "Namespace deleted"
        }
    } else {
        kubectl delete namespace $Namespace
        Write-Success "Namespace deleted"
    }
} else {
    Write-Status "📁 Keeping namespace '$Namespace' (use -DeleteNamespace to remove)"
}

# =============================================================================
# 7. Final Status
# =============================================================================
Write-Header "✅ Uninstall Summary"

Write-Success "Monitoring stack uninstall completed!"

Write-Status "What was removed:"
Write-Status "- Helm release: $ReleaseName"
if ($DeletePVCs) {
    Write-Status "- Persistent Volume Claims (monitoring data)"
} else {
    Write-Status "- Persistent Volume Claims: KEPT (data preserved)"
}
if ($DeleteNamespace) {
    Write-Status "- Namespace: $Namespace"
} else {
    Write-Status "- Namespace: KEPT ($Namespace)"
}

Write-Host ""
Write-Status "🔍 To verify removal:"
if (-not $DeleteNamespace) {
    Write-Status "kubectl get all -n $Namespace"
    Write-Status "helm list -n $Namespace"
}

if (-not $DeletePVCs -and -not $DeleteNamespace) {
    Write-Host ""
    Write-Status "💡 To completely remove everything including data:"
    Write-Status ".\uninstall-monitoring.ps1 -DeletePVCs -DeleteNamespace"
}

Write-Host ""
Write-Status "🎯 To reinstall monitoring:"
Write-Status ".\install-monitoring.ps1"

Write-Header "🎉 Uninstall Complete!"