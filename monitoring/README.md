# 🔍 Kubernetes Monitoring with Prometheus & Grafana

This directory contains everything you need to set up comprehensive monitoring for your EKS cluster using Prometheus and Grafana.

## 📊 What is Prometheus?

Prometheus is an open-source monitoring and alerting toolkit that:
- **Collects metrics** from your applications and infrastructure
- **Stores time-series data** with timestamps
- **Provides a query language (PromQL)** to analyze metrics
- **Sends alerts** when conditions are met
- **Scrapes metrics** from HTTP endpoints automatically

## 📈 What is Grafana?

Grafana is a visualization and analytics platform that:
- **Creates beautiful dashboards** from your metrics data
- **Connects to multiple data sources** (Prometheus, MySQL, etc.)
- **Provides alerting capabilities** with notifications
- **Offers templating** for dynamic dashboards
- **Supports team collaboration** with role-based access

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Your Apps    │────▶│   Prometheus     │────▶│    Grafana      │
│                │    │                  │    │                 │
│ /metrics       │    │ • Scrapes data   │    │ • Dashboards    │
│ endpoints      │    │ • Stores metrics │    │ • Visualization │
└─────────────────┘    │ • Alerting rules │    │ • Alerting UI   │
                       └──────────────────┘    └─────────────────┘
                                │
                       ┌──────────────────┐
                       │  Node Exporter   │
                       │                  │
                       │ • CPU, Memory    │
                       │ • Disk, Network  │
                       │ • System metrics │
                       └──────────────────┘
```

## 🔧 Automated Prerequisites Setup

The GitHub Actions workflow automatically handles:

### ✅ **EBS CSI Driver with IRSA**
- **OIDC Identity Provider**: Creates OpenID Connect provider for your EKS cluster
- **IAM Role**: Creates `AmazonEKS_EBS_CSI_DriverRole` with proper trust policy
- **Service Account**: Configures IRSA (IAM Roles for Service Accounts)
- **EBS CSI Addon**: Installs AWS EBS CSI driver addon with IAM role

### ✅ **Persistent Volume Support**
- **Storage Class**: Ensures `gp2` storage class is available
- **Volume Provisioning**: Enables dynamic PV provisioning for Prometheus & Grafana
- **EBS Volume Management**: Automatic EBS volume lifecycle management

### ✅ **Manual Setup Option**
If running outside GitHub Actions, use the dedicated setup script:
```bash
./setup-ebs-csi-driver.sh
```

## 🚀 Quick Start

### Prerequisites
- EKS cluster running
- `kubectl` configured
- `helm` installed
- **EBS CSI Driver** (automatically set up by GitHub Actions workflow)

### 1. Install Monitoring Stack

**Option A: Using GitHub Actions (Recommended)**
```bash
# Go to GitHub → Actions → "Deploy Monitoring Stack" workflow
# Select environment and action: install
# The workflow automatically handles all prerequisites including EBS CSI driver
```

**Option B: Manual Installation**
```bash
# If EBS CSI driver is not set up, run this first:
chmod +x setup-ebs-csi-driver.sh
./setup-ebs-csi-driver.sh

# Then install monitoring stack:
chmod +x install-monitoring.sh
./install-monitoring.sh
```

### 2. Access Grafana
```bash
# Forward Grafana port to localhost
chmod +x port-forward-grafana.sh
./port-forward-grafana.sh
```

### 3. Login to Grafana
- **URL**: http://localhost:3000
- **Username**: admin
- **Password**: Get it by running:
```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode && echo
```

## 📊 How to Access After Deployment

### **Grafana Dashboard (Recommended)**
Grafana provides the best visualization experience with pre-built dashboards.

1. **Get the Auto-Generated Password:**
   ```bash
   kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
   ```

2. **Port-Forward to Access:**
   ```bash
   cd monitoring
   ./port-forward-grafana.sh
   ```
   
3. **Visit Grafana:**
   - **URL**: http://localhost:3000
   - **Username**: `admin`
   - **Password**: Use the password from step 1

4. **Explore Pre-Built Dashboards:**
   - Navigate to **Dashboards → Browse**
   - Check out **Kubernetes** folder for cluster metrics
   - View **Node Exporter** dashboards for system metrics

### **Prometheus Query Interface**
Access the raw Prometheus interface for custom queries and debugging.

1. **Port-Forward Prometheus:**
   ```bash
   kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
   ```

2. **Visit Prometheus:**
   - **URL**: http://localhost:9090
   - **Features Available:**
     - Query metrics with PromQL
     - View targets and service discovery
     - Check alert rules and status
     - Explore metrics catalog

### **AlertManager Interface**
Manage and view alerts (if any are triggered).

1. **Port-Forward AlertManager:**
   ```bash
   kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093
   ```

2. **Visit AlertManager:**
   - **URL**: http://localhost:9093
   - View active alerts
   - Manage alert routing
   - Configure notification channels

### **Quick Access Scripts**
Use the provided convenience scripts:

```bash
# Access Grafana (recommended for daily use)
./port-forward-grafana.sh

# View all monitoring services
kubectl get svc -n monitoring

# Check pod status
kubectl get pods -n monitoring
```

## 📦 What Gets Installed

| Component | Purpose | Metrics |
|-----------|---------|----------|
| **Prometheus Server** | Core metrics collection & storage | Application & infrastructure metrics |
| **Grafana** | Visualization & dashboards | Beautiful charts and graphs |
| **Node Exporter** | Host metrics collector | CPU, Memory, Disk, Network |
| **kube-state-metrics** | Kubernetes object metrics | Pods, Services, Deployments |
| **Prometheus Operator** | Manages Prometheus instances | Auto-discovery of targets |
| **AlertManager** | Alert routing & notifications | Email, Slack, PagerDuty alerts |

## 🎯 Key Features Enabled

### ✅ Automatic Service Discovery
- Kubernetes services with annotations
- Pod metrics endpoints
- Node metrics from all cluster nodes

### ✅ Pre-configured Dashboards
- Kubernetes cluster overview
- Node metrics (CPU, memory, disk)
- Pod and container metrics
- Application performance

### ✅ Data Retention
- **Prometheus**: 7 days of metrics storage
- **Grafana**: Persistent dashboards and settings

## 🔧 Configuration

### Customize Installation
Edit `values.yaml` to modify:
- Resource limits and requests
- Storage configurations
- Grafana admin password
- Prometheus retention period
- Alert rules and notifications

### Add Custom Metrics
1. **Application Metrics**: Add `/metrics` endpoint to your apps
2. **Service Monitors**: Create ServiceMonitor resources
3. **Custom Dashboards**: Import or create in Grafana

## 📋 Verification Steps

### 1. Check All Pods are Running
```bash
kubectl get pods -n monitoring
```

### 2. Verify Prometheus Targets
```bash
# Forward Prometheus port
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```
Then visit: http://localhost:9090/targets

### 3. Check Grafana Dashboards
- Login to Grafana (see Quick Start above)
- Navigate to "Dashboards" → "Browse"
- Explore pre-installed Kubernetes dashboards

## 🎯 Accessing Your Kudos App Metrics

### Backend Metrics (if enabled)
If your Node.js backend exposes metrics:
```javascript
// In your server.js, add:
app.get('/metrics', (req, res) => {
  // Return Prometheus-format metrics
  res.set('Content-Type', 'text/plain');
  res.send('# Your custom metrics here');
});
```

### Frontend Metrics
For React apps, consider:
- User interactions
- Page load times
- API response times
- Error rates

## 🛠️ Useful Commands

```bash
# Get Grafana admin password
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode && echo

# Port forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Port forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Port forward to AlertManager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Check monitoring namespace resources
kubectl get all -n monitoring

# View Prometheus configuration
kubectl get prometheuses.monitoring.coreos.com -n monitoring -o yaml
```

## 🔄 Management Scripts

| Script | Purpose |
|--------|----------|
| `install-monitoring.sh` | Install complete monitoring stack |
| `uninstall-monitoring.sh` | Remove all monitoring components |
| `port-forward-grafana.sh` | Quick access to Grafana UI |

## 🚨 Troubleshooting

### Common Issues

**Pods stuck in Pending state:**
```bash
kubectl describe pods -n monitoring
# Check for resource constraints or node capacity
```

**Grafana login not working:**
```bash
# Reset Grafana admin password
kubectl delete secret -n monitoring kube-prometheus-stack-grafana
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f values.yaml
```

**Metrics not showing:**
- Check Prometheus targets: http://localhost:9090/targets
- Verify ServiceMonitor configurations
- Check network policies and firewall rules

### Logs and Debugging
```bash
# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Check Prometheus Operator logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator
```

## 📚 Learning Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Query Language](https://prometheus.io/docs/prometheus/latest/querying/)
- [Kubernetes Monitoring Best Practices](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-usage-monitoring/)

## 🎉 Next Steps

1. **Create Custom Dashboards**: Build dashboards specific to your Kudos app
2. **Set up Alerting**: Configure alerts for critical application metrics
3. **Add Log Aggregation**: Consider ELK stack or Loki for log monitoring
4. **Implement Tracing**: Add Jaeger for distributed tracing
5. **Security Monitoring**: Add security-focused metrics and alerts

Happy monitoring! 🚀