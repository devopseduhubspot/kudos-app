#!/bin/bash

# =============================================================================
# Grafana Port Forward Script
# =============================================================================
# This script creates a port forward to the Grafana service running in your
# Kubernetes cluster, making it accessible via http://localhost:3000
#
# What this script does:
# 1. Checks if the monitoring stack is installed
# 2. Retrieves the Grafana admin password
# 3. Sets up port forwarding to Grafana
# 4. Provides login instructions
# =============================================================================

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

# Handle script interruption (Ctrl+C)
cleanup() {
    echo
    print_status "🛑 Port forwarding stopped"
    print_status "Grafana is no longer accessible at http://localhost:3000"
    exit 0
}

# Set up trap to handle Ctrl+C gracefully
trap cleanup SIGINT SIGTERM

echo
print_status "🚀 Starting Grafana Port Forward..."
echo

# =============================================================================
# 1. Prerequisites Check
# =============================================================================
print_status "📋 Checking prerequisites..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    print_status "Please check your kubectl configuration"
    exit 1
fi

print_success "Prerequisites check passed!"
echo

# =============================================================================
# 2. Check if Monitoring Stack is Installed
# =============================================================================
print_status "🔍 Checking if monitoring stack is installed..."

# Check if monitoring namespace exists
if ! kubectl get namespace monitoring &> /dev/null; then
    print_error "Monitoring namespace not found"
    print_status "Please install the monitoring stack first:"
    print_status "  ./install-monitoring.sh"
    exit 1
fi

# Check if Grafana service exists
if ! kubectl get service -n monitoring kube-prometheus-stack-grafana &> /dev/null; then
    print_error "Grafana service not found in monitoring namespace"
    print_status "Please check if the monitoring stack is properly installed:"
    print_status "  kubectl get all -n monitoring"
    exit 1
fi

# Check if Grafana pods are running
GRAFANA_PODS_READY=$(kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana" --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$GRAFANA_PODS_READY" -eq 0 ]; then
    print_error "No running Grafana pods found"
    print_status "Checking pod status:"
    kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana"
    print_status "Please wait for Grafana pods to be ready or check the logs"
    exit 1
fi

print_success "Monitoring stack is installed and Grafana is running!"
echo

# =============================================================================
# 3. Get Grafana Admin Password
# =============================================================================
print_status "🔑 Retrieving Grafana admin password..."

# Get the admin password from the secret
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode 2>/dev/null)

if [ -z "$GRAFANA_PASSWORD" ]; then
    print_error "Could not retrieve Grafana admin password"
    print_status "You can manually get the password with:"
    print_status "  kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode && echo"
else
    print_success "Grafana admin password retrieved successfully!"
fi
echo

# =============================================================================
# 4. Check if Port 3000 is Available
# =============================================================================
print_status "🔌 Checking if port 3000 is available..."

# Check if port 3000 is already in use
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_warning "Port 3000 is already in use"
    print_status "The following process is using port 3000:"
    lsof -Pi :3000 -sTCP:LISTEN 2>/dev/null || echo "Unable to determine the process"
    echo
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Port forwarding cancelled"
        exit 0
    fi
else
    print_success "Port 3000 is available!"
fi
echo

# =============================================================================
# 5. Display Connection Information
# =============================================================================
print_success "🎯 Grafana Access Information:"
echo
echo "📍 URL:      http://localhost:3000"
echo "👤 Username: admin"
if [ -n "$GRAFANA_PASSWORD" ]; then
    echo "🔑 Password: $GRAFANA_PASSWORD"
else
    echo "🔑 Password: [Run the command shown above to get password]"
fi
echo
print_status "📊 Pre-installed Dashboards:"
echo "   • Kubernetes / Compute Resources / Cluster"
echo "   • Kubernetes / Compute Resources / Namespace (Pods)"
echo "   • Kubernetes / Compute Resources / Node (Pods)"
echo "   • Node Exporter / Nodes"
echo "   • Prometheus / Overview"
echo

# =============================================================================
# 6. Start Port Forwarding
# =============================================================================
print_status "🌐 Starting port forward to Grafana..."
print_status "Grafana will be accessible at http://localhost:3000"
print_warning "Press Ctrl+C to stop port forwarding"
echo

# Start the port forward
# Note: This will run until interrupted
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80