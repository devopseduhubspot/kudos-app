# Prometheus Commands Reference - Kudos App & Kubernetes Monitoring

This document contains essential Prometheus queries for monitoring the Kudos application and Kubernetes infrastructure.

## 📊 **Kudos Application Specific Commands**

### 1. **Kudos App Pod Status**
```promql
kube_pod_info{namespace="default", pod=~"kudos.*"}
```
Shows all pods related to the Kudos application in the default namespace.

### 2. **Kudos App Pod CPU Usage**
```promql
rate(container_cpu_usage_seconds_total{namespace="default", pod=~"kudos.*"}[5m])
```
CPU usage rate for Kudos app containers over the last 5 minutes.

### 3. **Kudos App Memory Usage**
```promql
container_memory_usage_bytes{namespace="default", pod=~"kudos.*"} / 1024 / 1024
```
Memory usage in MB for Kudos application containers.

### 4. **Kudos App Container Restarts**
```promql
increase(kube_pod_container_status_restarts_total{namespace="default", pod=~"kudos.*"}[1h])
```
Number of container restarts in the last hour for Kudos app.

### 5. **Kudos App Service Endpoints**
```promql
kube_service_info{namespace="default", service=~"kudos.*"}
```
Information about Kudos application services.

### 6. **Kudos App Deployment Status**
```promql
kube_deployment_status_replicas_available{namespace="default", deployment=~"kudos.*"} / kube_deployment_spec_replicas{namespace="default", deployment=~"kudos.*"}
```
Ratio of available vs desired replicas for Kudos deployments.

## 🔧 **Kubernetes Infrastructure Monitoring Commands**

### 7. **Node CPU Usage**
```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```
CPU utilization percentage for each node in the cluster.

### 8. **Node Memory Usage**
```promql
((node_memory_MemTotal_bytes - node_memory_MemFree_bytes - node_memory_Cached_bytes - node_memory_Buffers_bytes) / node_memory_MemTotal_bytes) * 100
```
Memory usage percentage for each node.

### 9. **Node Disk Usage**
```promql
100 - ((node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"}) * 100)
```
Disk usage percentage excluding temporary filesystems.

### 10. **Total Running Pods**
```promql
count(kube_pod_info{phase="Running"})
```
Total number of running pods across all namespaces.

### 11. **Pods by Namespace**
```promql
count(kube_pod_info) by (namespace)
```
Count of pods grouped by namespace.

### 12. **Node Load Average**
```promql
node_load1
```
1-minute load average for each node.

### 13. **Kubernetes API Server Requests**
```promql
rate(apiserver_request_total[5m])
```
Rate of requests to the Kubernetes API server.

### 14. **Container Network Receive Bytes**
```promql
rate(container_network_receive_bytes_total{pod!=""}[5m])
```
Network receive rate for containers.

### 15. **Container Network Transmit Bytes**
```promql
rate(container_network_transmit_bytes_total{pod!=""}[5m])
```
Network transmit rate for containers.

## ⚠️ **Alert Condition Commands**

### 16. **High CPU Alert (>80%)**
```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
```
Identifies nodes with CPU usage above 80%.

### 17. **High Memory Alert (>85%)**
```promql
((node_memory_MemTotal_bytes - node_memory_MemFree_bytes - node_memory_Cached_bytes - node_memory_Buffers_bytes) / node_memory_MemTotal_bytes) * 100 > 85
```
Identifies nodes with memory usage above 85%.

### 18. **Pod Not Ready**
```promql
kube_pod_status_ready{condition="false"} == 1
```
Shows pods that are not in ready state.

### 19. **Persistent Volume Usage (>90%)**
```promql
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 90
```
Identifies persistent volumes with usage above 90%.

### 20. **Container OOM Kills**
```promql
increase(container_oom_kills_total[1h]) > 0
```
Shows containers that have been killed due to out-of-memory in the last hour.

## 🚀 **Usage Instructions**

### Access Prometheus UI:
1. **Start Port Forward:**
   ```bash
   kubectl port-forward -n monitoring service/kube-prometheus-stack-prometheus 9090:9090
   ```

2. **Open Browser:**
   ```
   http://localhost:9090
   ```

3. **Execute Queries:**
   - Click on "Graph" tab
   - Paste any query from above
   - Click "Execute"
   - Switch between "Graph" and "Table" views

### Query Tips:
- **Time Range:** Adjust using the time picker (e.g., 5m, 1h, 24h)
- **Labels:** Use `{label="value"}` for filtering
- **Regex:** Use `{label=~"pattern.*"}` for pattern matching
- **Functions:** Combine with `rate()`, `avg()`, `sum()`, `max()`, etc.

### Common PromQL Functions:
- `rate()` - Per-second average rate of increase
- `increase()` - Total increase over time range
- `avg()` - Average value
- `sum()` - Sum of values
- `max()` / `min()` - Maximum/minimum values
- `by(label)` - Group by label
- `histogram_quantile()` - Calculate quantiles from histograms

## 📈 **Creating Dashboards in Grafana**

These queries can be used to create comprehensive dashboards in Grafana:

1. **Infrastructure Dashboard:** Use queries 7-15
2. **Application Dashboard:** Use queries 1-6
3. **Alerts Dashboard:** Use queries 16-20

### Access Grafana:
1. **Start Port Forward:**
   ```bash
   kubectl port-forward -n monitoring service/kube-prometheus-stack-grafana 3000:80
   ```

2. **Login:**
   - URL: http://localhost:3000
   - Username: admin
   - Password: `JW8TirtDEWucjalSuKelNjbRQ9bG8wMQJJDSRN6L`

## 📊 **Importing Pre-built Grafana Dashboards**

Instead of creating dashboards from scratch, you can import popular community dashboards for Kubernetes monitoring.

### **Step-by-Step Dashboard Import Process:**

#### 1. **Access Grafana**
```bash
kubectl port-forward -n monitoring service/kube-prometheus-stack-grafana 3000:80
```
- URL: http://localhost:3000
- Username: admin  
- Password: `JW8TirtDEWucjalSuKelNjbRQ9bG8wMQJJDSRN6L`

#### 2. **Import Dashboard**
1. **Navigate to Import:**
   - Click the **"+"** icon in the left sidebar
   - Select **"Import"**

2. **Import Methods:**
   
   **Method A: Using Dashboard ID**
   - Enter dashboard ID (see popular IDs below)
   - Click **"Load"**
   
   **Method B: Upload JSON**
   - Click **"Upload JSON file"**
   - Select downloaded dashboard JSON
   
   **Method C: Paste JSON**
   - Copy dashboard JSON content
   - Paste in the text area

#### 3. **Configure Data Source**
- **Data Source:** Select `Prometheus` (should be auto-detected)
- **Folder:** Choose appropriate folder or create new one
- Click **"Import"**

### **🎯 Popular Kubernetes Dashboards**

#### **Node/Infrastructure Dashboards:**

**1. Node Exporter Full (ID: 1860)**
```
Dashboard ID: 1860
Description: Comprehensive node monitoring with CPU, memory, disk, network
Data Source: Prometheus
```

**2. Kubernetes Cluster Monitoring (ID: 8588)**  
```
Dashboard ID: 8588
Description: Overall cluster health and resource usage
Data Source: Prometheus
```

**3. Kubernetes Node Exporter (ID: 11074)**
```
Dashboard ID: 11074
Description: Detailed node metrics and system monitoring
Data Source: Prometheus
```

#### **Pod/Container Dashboards:**

**4. Kubernetes Pods (ID: 6417)**
```
Dashboard ID: 6417
Description: Pod resource usage, restarts, and status
Data Source: Prometheus
```

**5. Kubernetes Deployment Statefulset Daemonset (ID: 8588)**
```
Dashboard ID: 8588
Description: Workload monitoring across different resource types
Data Source: Prometheus
```

#### **Application Dashboards:**

**6. Kubernetes App Metrics (ID: 1471)**
```
Dashboard ID: 1471
Description: Application-specific metrics and performance
Data Source: Prometheus
```

**7. Kubernetes Ingress Controller (ID: 9614)**
```
Dashboard ID: 9614
Description: Ingress traffic and performance metrics
Data Source: Prometheus
```

### **🎨 Customizing Imported Dashboards**

After importing, you can customize dashboards for the Kudos app:

#### **1. Filter for Kudos App:**
- **Edit Panel:** Click panel title → "Edit"
- **Add Filters:** Modify queries to include:
  ```promql
  {namespace="default", pod=~"kudos.*"}
  ```

#### **2. Create Kudos-Specific Variables:**
- **Settings:** Click gear icon → "Variables"
- **Add Variable:**
  ```
  Name: kudos_namespace
  Type: Query
  Query: label_values(kube_pod_info{pod=~"kudos.*"}, namespace)
  ```

#### **3. Customize Panel Titles:**
- Change generic titles to Kudos-specific ones:
  - "Pod CPU Usage" → "Kudos App CPU Usage"
  - "Memory Usage" → "Kudos App Memory Usage"

### **🔄 Dashboard Management Best Practices**

#### **1. Organization:**
```
Folder Structure:
├── Infrastructure/
│   ├── Node Monitoring (ID: 1860)
│   ├── Cluster Overview (ID: 8588)
│   └── Storage Monitoring
├── Applications/
│   ├── Kudos App Dashboard (Custom)
│   ├── Pod Monitoring (ID: 6417)
│   └── Ingress Metrics (ID: 9614)
└── Alerts/
    ├── Critical Alerts
    └── Warning Alerts
```

#### **2. Dashboard Maintenance:**
- **Star Important Dashboards:** Click star icon for quick access
- **Set Default Dashboard:** Home → Preferences → Set home dashboard
- **Regular Updates:** Check for dashboard updates in Grafana.com

#### **3. Sharing and Export:**
```bash
# Export dashboard JSON
Dashboard Settings → JSON Model → Copy to clipboard

# Share dashboard
Dashboard Settings → Share → Get shareable link
```

### **📋 Quick Import Commands**

For rapid setup, here are the essential dashboard IDs:

```bash
# Essential Kubernetes Dashboards to Import:
1860  # Node Exporter Full
8588  # Kubernetes Cluster Monitoring  
6417  # Kubernetes Pods
9614  # Kubernetes Ingress Controller
1471  # Kubernetes App Metrics
```

### **🎯 Kudos App Specific Dashboard Creation**

After importing base dashboards, create a custom Kudos dashboard:

#### **1. Create New Dashboard:**
- Click **"+"** → **"Dashboard"**
- **Add Panel** → **"Add Query"**

#### **2. Essential Kudos Panels:**
```json
{
  "panels": [
    {
      "title": "Kudos App Pod Status",
      "query": "kube_pod_info{namespace=\"default\", pod=~\"kudos.*\"}"
    },
    {
      "title": "Kudos App CPU Usage", 
      "query": "rate(container_cpu_usage_seconds_total{namespace=\"default\", pod=~\"kudos.*\"}[5m])"
    },
    {
      "title": "Kudos App Memory Usage",
      "query": "container_memory_usage_bytes{namespace=\"default\", pod=~\"kudos.*\"} / 1024 / 1024"
    },
    {
      "title": "Kudos App HTTP Requests",
      "query": "rate(http_requests_total{namespace=\"default\", pod=~\"kudos.*\"}[5m])"
    }
  ]
}
```

#### **3. Save Custom Dashboard:**
- **Save:** Click save icon (disk)
- **Name:** "Kudos Application Monitoring"
- **Folder:** Applications
- **Tags:** kudos, nodejs, application

---

**Note:** Replace `kudos.*` patterns with your actual application naming conventions if different. These queries assume the default namespace for the Kudos application.