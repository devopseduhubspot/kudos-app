#!/bin/bash

# =============================================================================
# Kubernetes Monitoring Stack Installer
# =============================================================================
# This script installs Prometheus and Grafana on your EKS cluster using Helm
# 
# Components installed:
# - Prometheus (metrics collection and storage)
# - Grafana (visualization and dashboards)
# - Node Exporter (system metrics from cluster nodes)
# - kube-state-metrics (Kubernetes object metrics)
# - AlertManager (alert routing and notifications)
# =============================================================================

set -e  # Exit on any error

# Set default timeout if not provided
HELM_TIMEOUT=${HELM_TIMEOUT:-"10m"}

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

print_status "🚀 Starting Kubernetes Monitoring Stack Installation..."
echo

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
    print_status "Please install Helm: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    print_status "Please check your kubectl configuration"
    exit 1
fi

print_success "All prerequisites met!"
echo

# =============================================================================
# 2. Create Monitoring Namespace
# =============================================================================
print_status "🏗️  Creating monitoring namespace..."

# Create namespace if it doesn't exist
if kubectl get namespace monitoring &> /dev/null; then
    print_warning "Namespace 'monitoring' already exists"
else
    kubectl create namespace monitoring
    print_success "Created namespace 'monitoring'"
fi
echo

# =============================================================================
# 3. Add Prometheus Community Helm Repository
# =============================================================================
print_status "📦 Adding Prometheus Community Helm repository..."

# Add the repository (this is idempotent)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

print_success "Helm repository added and updated!"
echo

# =============================================================================
# 4. Install kube-prometheus-stack
# =============================================================================
print_status "⚙️  Installing kube-prometheus-stack..."
print_status "This may take 2-5 minutes depending on your cluster..."
echo

# Install or upgrade the monitoring stack
if helm list -n monitoring | grep -q kube-prometheus-stack; then
    print_warning "kube-prometheus-stack already installed, upgrading..."
    helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values values.yaml \
        --wait \
        --timeout=$HELM_TIMEOUT
else
    helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values values.yaml \
        --wait \
        --timeout=$HELM_TIMEOUT
fi

print_success "kube-prometheus-stack installed successfully!"
echo

# =============================================================================
# 5. Verify Installation
# =============================================================================
print_status "🔍 Verifying installation..."
echo

# Wait for all pods to be ready
print_status "Waiting for all pods to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l "release=kube-prometheus-stack" -n monitoring --timeout=600s

print_success "All monitoring pods are ready!"
echo

# =============================================================================
# 6. Display Installation Summary
# =============================================================================
print_success "🎉 Monitoring Stack Installation Complete!"
echo
print_status "📊 Installed Components:"
echo "   ✅ Prometheus Server (metrics collection)"
echo "   ✅ Grafana (visualization dashboards)"
echo "   ✅ AlertManager (alert notifications)"
echo "   ✅ Node Exporter (system metrics)"
echo "   ✅ kube-state-metrics (K8s object metrics)"
echo "   ✅ Prometheus Operator (management)"
echo

# =============================================================================
# 7. Display Access Information
# =============================================================================
print_status "🌐 Access Information:"
echo
echo "📈 Grafana Dashboard:"
echo "   1. Run: ./port-forward-grafana.sh"
echo "   2. Open: http://localhost:3000"
echo "   3. Username: admin"
echo "   4. Password: Run this command:"
echo "      kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode && echo"
echo
echo "🔍 Prometheus UI:"
echo "   kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "   Then open: http://localhost:9090"
echo
echo "🚨 AlertManager UI:"
echo "   kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
echo "   Then open: http://localhost:9093"
echo

# =============================================================================
# 8. Display Useful Commands
# =============================================================================
print_status "🛠️  Useful Commands:"
echo
echo "# Check all monitoring pods:"
echo "kubectl get pods -n monitoring"
echo
echo "# Get Grafana admin password:"
echo "kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode && echo"
echo
echo "# View all monitoring resources:"
echo "kubectl get all -n monitoring"
echo
echo "# Uninstall monitoring stack:"
echo "./uninstall-monitoring.sh"
echo

print_success "🎊 Installation completed successfully!"
print_status "📚 Check the README.md for detailed usage instructions."
echo