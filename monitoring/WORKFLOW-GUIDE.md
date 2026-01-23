# 🔧 Monitoring Deployment Workflow Guide

This document explains how to use the GitHub Actions workflow to deploy and manage Prometheus/Grafana monitoring on your EKS cluster.

## 🚀 Quick Start

### 1. **Install Monitoring Stack**
1. Go to **Actions** tab in your GitHub repository
2. Select **"monitoring-deployment"** workflow
3. Click **"Run workflow"**
4. Configure:
   - **Environment**: `dev` (or `staging`/`prod`)
   - **Action**: `install`
   - **Helm Timeout**: `10` (minutes)
5. Click **"Run workflow"**

### 2. **Access Grafana Dashboard**
After installation completes:
```bash
# Port forward to access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Get admin password
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode && echo
```
Then open: http://localhost:3000 (Username: `admin`)

### 3. **Uninstall When Done**
1. Go to **Actions** → **"monitoring-deployment"**
2. Click **"Run workflow"**
3. Configure:
   - **Environment**: `dev` (match your install environment)
   - **Action**: `uninstall`
4. Click **"Run workflow"**

## 📊 Workflow Features

| Feature | Description |
|---------|-------------|
| **Multi-Environment** | Deploy to dev, staging, or prod |
| **Safe Operations** | Comprehensive checks before deployment |
| **Status Reporting** | Detailed logs and status information |
| **Rollback Support** | Easy uninstall when needed |
| **Artifact Reports** | Generated reports for each deployment |

## 🎯 Workflow Inputs

### Environment Selection
- **`dev`**: Development cluster (kudos-app-dev)
- **`staging`**: Staging cluster (kudos-app-staging) 
- **`prod`**: Production cluster (kudos-app-prod)

### Action Types
- **`install`**: Deploy monitoring stack
- **`uninstall`**: Remove monitoring stack completely
- **`status`**: Check current monitoring status

### Helm Timeout
- Default: `10` minutes
- Increase for slower clusters or large deployments
- Decrease for faster deployments

## 🔍 What Gets Installed

The workflow installs these components in the `monitoring` namespace:

### Core Components
- ✅ **Prometheus Server** - Metrics collection and storage (7 days retention)
- ✅ **Grafana** - Beautiful dashboards and visualization
- ✅ **AlertManager** - Alert routing and notifications
- ✅ **Node Exporter** - System metrics from all cluster nodes
- ✅ **kube-state-metrics** - Kubernetes object metrics
- ✅ **Prometheus Operator** - Automatic Prometheus management

### Pre-configured Dashboards
- Kubernetes cluster overview
- Node performance metrics
- Pod and container metrics
- Application performance monitoring
- System resource utilization

## 📋 Monitoring Your Kudos App

After installation, your Kudos application will automatically be monitored:

### Automatically Collected Metrics
- **Pod CPU and Memory usage**
- **Network traffic and errors** 
- **Container restart counts**
- **Service response times**
- **Kubernetes deployment status**

### Custom Application Metrics
To add custom metrics to your Kudos backend, add this to your `server.js`:

```javascript
// Add Prometheus metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(`
# HELP kudos_total Total number of kudos created
# TYPE kudos_total counter
kudos_total ${kudosData.length}

# HELP kudos_likes_total Total number of likes received
# TYPE kudos_likes_total counter
kudos_likes_total ${kudosData.reduce((sum, k) => sum + k.likes, 0)}

# HELP active_users_total Number of unique users
# TYPE active_users_total gauge
active_users_total ${users.size}
  `);
});
```

## 🛠️ Troubleshooting

### Common Issues and Solutions

**Workflow fails with "cluster not found":**
```bash
# Check if cluster exists and is accessible
aws eks list-clusters --region us-east-1
aws eks describe-cluster --name kudos-app-dev --region us-east-1
```

**Helm timeout during installation:**
- Increase the timeout value to 15-20 minutes
- Check node capacity: `kubectl get nodes`
- Check pending pods: `kubectl get pods -n monitoring`

**Grafana login not working:**
```bash
# Reset Grafana admin password
kubectl delete secret -n monitoring kube-prometheus-stack-grafana
# Then re-run the install workflow
```

**Monitoring not showing application metrics:**
- Ensure your app exposes `/metrics` endpoint
- Check Prometheus targets: http://localhost:9090/targets
- Verify service discovery annotations

### Debug Commands

```bash
# Check workflow deployment status
kubectl get all -n monitoring

# View pod logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus

# Check Helm releases
helm list -n monitoring

# Verify persistent storage
kubectl get pvc -n monitoring
```

## 🔄 Environment Management

### Dev Environment
- **Cluster**: `kudos-app-dev`
- **Purpose**: Development and testing
- **Resources**: Lower resource limits for cost efficiency
- **Retention**: 7 days metrics retention

### Staging Environment  
- **Cluster**: `kudos-app-staging`
- **Purpose**: Pre-production testing
- **Resources**: Production-like resource allocation
- **Retention**: 7 days metrics retention

### Production Environment
- **Cluster**: `kudos-app-prod`  
- **Purpose**: Live production workloads
- **Resources**: High availability and performance
- **Retention**: Consider increasing to 30+ days

## 📈 Best Practices

### 1. **Environment Strategy**
- Always test in `dev` before `staging`
- Test in `staging` before `prod`
- Use same workflow for consistency

### 2. **Resource Management**
- Monitor cluster resources before installation
- Adjust `values.yaml` for different environments
- Consider node auto-scaling for monitoring workloads

### 3. **Data Management**
- Monitor storage usage for Prometheus data
- Plan for backup strategy in production
- Consider longer retention for production metrics

### 4. **Security**
- Change default Grafana password in production
- Implement proper RBAC for monitoring access
- Secure external access with proper authentication

## 🎯 Next Steps After Installation

1. **Explore Dashboards**: Browse pre-installed Kubernetes dashboards
2. **Create Custom Dashboards**: Build dashboards specific to your application
3. **Set up Alerts**: Configure alerts for critical application metrics
4. **Add Log Aggregation**: Consider adding ELK or Loki for log monitoring
5. **Implement Tracing**: Add Jaeger for distributed tracing

## 📞 Support

If you encounter issues:
1. Check the workflow run logs in GitHub Actions
2. Review the generated monitoring report artifact
3. Use the debug commands provided above
4. Check the main [monitoring README](./monitoring/README.md) for detailed information

Happy monitoring! 🚀