#!/bin/bash

# =============================================================================
# Kubernetes Monitoring Stack Uninstaller
# =============================================================================
# This script removes the complete Prometheus and Grafana monitoring stack
# from your EKS cluster.
#
# WARNING: This will delete:
# - All monitoring dashboards
# - All stored metrics data
# - All custom configurations
# - The monitoring namespace (optional)
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo
print_warning "⚠️  KUBERNETES MONITORING STACK REMOVAL"
echo
print_warning "This will permanently delete:"
echo "   • All Prometheus metrics data"
echo "   • All Grafana dashboards and settings"
echo "   • All AlertManager configurations"
echo "   • Custom monitoring configurations"
echo
echo "The following components will be removed:"
echo "   - Prometheus Server"
echo "   - Grafana"
echo "   - AlertManager"
echo "   - Node Exporter"
echo "   - kube-state-metrics"
echo "   - Prometheus Operator"
echo

#!/bin/bash

# =============================================================================
# Kubernetes Monitoring Stack Uninstaller
# =============================================================================
# This script removes the complete Prometheus and Grafana monitoring stack
# from your EKS cluster.
#
# WARNING: This will delete:
# - All monitoring dashboards
# - All stored metrics data
# - All custom configurations
# - The monitoring namespace (optional)
#
# Environment Variables for Automation:
# - AUTO_CONFIRM: Set to 'true' to skip main confirmation
# - DELETE_PVCS: Set to 'true' to automatically delete PVCs
# - DELETE_NAMESPACE: Set to 'true' to automatically delete namespace
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for automation mode
if [[ "${AUTO_CONFIRM}" == "true" ]]; then
    print_status "🤖 Running in automated mode..."
    print_status "   AUTO_CONFIRM: ${AUTO_CONFIRM:-false}"
    print_status "   DELETE_PVCS: ${DELETE_PVCS:-false}"
    print_status "   DELETE_NAMESPACE: ${DELETE_NAMESPACE:-false}"
    echo
fi

echo
print_warning "⚠️  KUBERNETES MONITORING STACK REMOVAL"
echo
print_warning "This will permanently delete:"
echo "   • All Prometheus metrics data"
echo "   • All Grafana dashboards and settings"
echo "   • All AlertManager configurations"
echo "   • Custom monitoring configurations"
echo
echo "The following components will be removed:"
echo "   - Prometheus Server"
echo "   - Grafana"
echo "   - AlertManager"
echo "   - Node Exporter"
echo "   - kube-state-metrics"
echo "   - Prometheus Operator"
echo

# Confirmation prompt
if [[ "${AUTO_CONFIRM}" != "true" ]]; then
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Uninstallation cancelled."
        exit 0
    fi
    echo
else
    print_status "🤖 Auto-confirming uninstallation..."
fi

# =============================================================================
# 1. Prerequisites Check
# =============================================================================
print_status "📋 Checking prerequisites..."

# Check if kubectl is installed and working
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_success "Prerequisites check passed!"
echo

# =============================================================================
# 2. Check if Monitoring Stack is Installed
# =============================================================================
print_status "🔍 Checking if monitoring stack is installed..."

# Check if the monitoring namespace exists
if ! kubectl get namespace monitoring &> /dev/null; then
    print_warning "Monitoring namespace does not exist"
    print_status "Nothing to uninstall."
    exit 0
fi

# Check if the Helm release exists
if ! helm list -n monitoring | grep -q kube-prometheus-stack; then
    print_warning "kube-prometheus-stack Helm release not found"
    print_status "Checking for resources in monitoring namespace..."
    
    RESOURCES=$(kubectl get all -n monitoring 2>/dev/null || true)
    if [ -z "$RESOURCES" ] || [ "$RESOURCES" = "No resources found in monitoring namespace." ]; then
        print_status "No resources found in monitoring namespace"
        read -p "Do you want to delete the empty monitoring namespace? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete namespace monitoring
            print_success "Empty monitoring namespace deleted"
        fi
        exit 0
    fi
fi

print_success "Monitoring stack found!"
echo

# =============================================================================
# 3. Display What Will Be Removed
# =============================================================================
print_status "📦 Resources that will be removed:"
echo
kubectl get all -n monitoring
echo

# =============================================================================
# 4. Uninstall Helm Release
# =============================================================================
print_status "🗑️  Uninstalling kube-prometheus-stack Helm release..."

if helm list -n monitoring | grep -q kube-prometheus-stack; then
    helm uninstall kube-prometheus-stack -n monitoring
    print_success "Helm release uninstalled successfully!"
else
    print_warning "Helm release not found, skipping..."
fi
echo

# =============================================================================
# 5. Clean Up Persistent Volume Claims
# =============================================================================
print_status "💾 Handling Persistent Volume Claims..."

# Check if PVCs exist
PVC_COUNT=$(kubectl get pvc -n monitoring --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$PVC_COUNT" -gt 0 ]; then
    print_warning "Found $PVC_COUNT Persistent Volume Claims in monitoring namespace:"
    kubectl get pvc -n monitoring
    echo
    print_warning "⚠️  Deleting PVCs will permanently delete all monitoring data!"
    echo
    
    # Check if we should auto-delete PVCs
    if [[ "${DELETE_PVCS}" == "true" ]]; then
        print_status "🤖 Auto-confirming PVC deletion..."
        REPLY="y"
    else
        read -p "Do you want to delete PVCs and all monitoring data? (y/N): " -n 1 -r
        echo
    fi
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deleting Persistent Volume Claims..."
        kubectl delete pvc --all -n monitoring --ignore-not-found=true
        
        # Wait for PVCs to be deleted
        print_status "Waiting for PVC deletion..."
        while [ "$(kubectl get pvc -n monitoring --no-headers 2>/dev/null | wc -l)" -gt 0 ]; do
            echo -n "."
            sleep 2
        done
        echo
        print_success "All PVCs deleted successfully!"
    else
        print_status "Keeping PVCs and monitoring data"
        print_warning "Note: PVCs will persist and retain monitoring data"
    fi
else
    print_status "No PVCs found in monitoring namespace"
fi
echo

# =============================================================================
# 7. Clean Up Remaining Resources
# =============================================================================
print_status "🧹 Cleaning up remaining resources..."

# Wait for pods to terminate
print_status "Waiting for pods to terminate..."
sleep 10

# Force delete any remaining pods
REMAINING_PODS=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l)
if [ "$REMAINING_PODS" -gt 0 ]; then
    print_warning "Found $REMAINING_PODS remaining pods, force deleting..."
    kubectl delete pods --all -n monitoring --force --grace-period=0 2>/dev/null || true
fi

# Clean up any remaining resources
print_status "Removing any remaining Custom Resource Definitions..."

# Remove Prometheus CRDs (be careful not to affect other Prometheus instances)
kubectl get crd | grep monitoring.coreos.com | awk '{print $1}' | xargs -I {} kubectl delete crd {} --ignore-not-found=true 2>/dev/null || true

# Remove any remaining secrets, configmaps, and services
kubectl delete secrets,configmaps,services,deployments,statefulsets,daemonsets --all -n monitoring --ignore-not-found=true 2>/dev/null || true

print_success "Resource cleanup completed!"
echo

# =============================================================================
# 8. Namespace Deletion
# =============================================================================
print_status "🗂️  Handling monitoring namespace..."
echo

# Check if we should auto-delete namespace
if [[ "${DELETE_NAMESPACE}" == "true" ]]; then
    print_status "🤖 Auto-confirming namespace deletion..."
    REPLY="y"
else
    read -p "Do you want to delete the 'monitoring' namespace? (y/N): " -n 1 -r
    echo
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Deleting monitoring namespace..."
    kubectl delete namespace monitoring --ignore-not-found=true
    
    # Wait for namespace to be fully deleted
    print_status "Waiting for namespace deletion to complete..."
    while kubectl get namespace monitoring &> /dev/null; do
        echo -n "."
        sleep 2
    done
    echo
    print_success "Monitoring namespace deleted successfully!"
else
    print_status "Keeping monitoring namespace for potential future use"
fi
echo

# =============================================================================
# 9. Verification
# =============================================================================
print_status "✅ Verifying removal..."

# Check if any monitoring pods are still running
REMAINING_PODS=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$REMAINING_PODS" -eq 0 ]; then
    print_success "No monitoring pods remaining"
else
    print_warning "$REMAINING_PODS pods still exist in monitoring namespace"
    kubectl get pods -n monitoring
fi

# Check Helm releases
HELM_RELEASES=$(helm list -n monitoring 2>/dev/null | grep -v NAME | wc -l || echo "0")
if [ "$HELM_RELEASES" -eq 0 ]; then
    print_success "No monitoring Helm releases remaining"
else
    print_warning "Some Helm releases still exist:"
    helm list -n monitoring
fi

echo

# =============================================================================
# 10. Final Summary
# =============================================================================
print_success "🎉 Monitoring Stack Removal Complete!"
echo
print_status "✅ Removed Components:"
echo "   • Prometheus Server"
echo "   • Grafana Dashboards"  
echo "   • AlertManager"
echo "   • Node Exporter"
echo "   • kube-state-metrics"
echo "   • Prometheus Operator"
echo "   • Persistent Volume Claims (if selected)"
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   • monitoring namespace"
fi
echo

print_status "💡 To reinstall the monitoring stack:"
echo "   ./install-monitoring.sh"
echo
print_success "✨ Uninstallation completed successfully!"
echo