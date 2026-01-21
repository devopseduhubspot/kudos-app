# 🚀 Kubernetes Deployment Guide - Full-Stack Kudos App

## 📋 Overview

This guide covers the complete deployment of both frontend and backend services to your EKS Kubernetes cluster.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Internet      │    │   LoadBalancer  │    │   Frontend      │
│   Users         │───▶│   (Port: 80)    │───▶│   (nginx:80)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                      │ API Calls
                                                      ▼
                                              ┌─────────────────┐
                                              │   Backend       │
                                              │   (Node.js)     │
                                              │   Port: 3001    │
                                              └─────────────────┘
```

## 📦 New Components Added

### Backend Service
- **Image**: `kudos-app-backend-{env}:latest`
- **Port**: 3001
- **Endpoints**: `/health`, `/api/kudos`, `/api/stats`
- **Replicas**: 2 (auto-scaling 1-3)

### Frontend Updates
- **Nginx proxy**: Routes `/api/*` to backend service
- **Environment**: Uses ConfigMap for API URL
- **Replicas**: 2 (auto-scaling 1-5)

## 📁 Updated Files

### Kubernetes Manifests (`k8s/`)
```
├── configmap.yaml      # Environment configuration
├── deployment.yaml     # Frontend + Backend deployments
├── service.yaml        # Frontend + Backend services
├── hpa.yaml           # Auto-scaling for both services
├── ingress.yaml       # External access (unchanged)
└── kustomization.yaml # Resource list
```

### Docker & CI/CD
```
├── Dockerfile.backend          # Backend container build
├── server/.dockerignore       # Backend build optimization
└── .github/workflows/
    └── main-ci-cd-manual.yml  # Updated for dual builds
```

## 🔧 Deployment Process

### 1. Manual Deployment
If you want to deploy manually using kubectl:

```bash
# Apply all Kubernetes resources
kubectl apply -k k8s/

# Check deployment status
kubectl get deployments
kubectl get pods
kubectl get services

# Check logs
kubectl logs -l app=kudos-frontend
kubectl logs -l app=kudos-backend
```

### 2. CI/CD Pipeline Deployment (Recommended)
Use the updated GitHub Actions workflow:

1. Go to GitHub Actions
2. Run "main-ci-cd-manual" workflow
3. Select your environment (dev/staging/prod)
4. Choose "full-pipeline"

The pipeline now:
- ✅ Builds both frontend and backend images
- ✅ Pushes to separate ECR repositories
- ✅ Deploys both services to Kubernetes
- ✅ Performs health checks on both services
- ✅ Configures auto-scaling for both

## 📊 New ECR Repositories

The pipeline creates environment-specific repositories:

**Frontend:**
- `kudos-app-dev`
- `kudos-app-staging` 
- `kudos-app-prod`

**Backend:**
- `kudos-app-backend-dev`
- `kudos-app-backend-staging`
- `kudos-app-backend-prod`

## 🔍 Verification Steps

### 1. Check All Services Are Running
```bash
kubectl get all -l app=kudos-frontend
kubectl get all -l app=kudos-backend
```

### 2. Test Backend Health
```bash
kubectl port-forward svc/kudos-backend 3001:3001
curl http://localhost:3001/health
```

### 3. Test Frontend Access
```bash
kubectl port-forward svc/kudos-frontend 8080:80
curl http://localhost:8080
```

### 4. Test Full Integration
```bash
# Get the LoadBalancer URL
kubectl get svc kudos-frontend

# Test the full application
curl http://<EXTERNAL-IP>/
curl http://<EXTERNAL-IP>/api/kudos
```

## 🔧 Environment Configuration

### ConfigMap Variables
```yaml
VITE_API_URL: "/api"      # Frontend uses nginx proxy
PORT: "3001"              # Backend port
NODE_ENV: "production"    # Backend environment
```

### Service Communication
- Frontend → Backend: `http://kudos-backend:3001`
- External → Frontend: `http://<LoadBalancer>/`
- External → Backend API: `http://<LoadBalancer>/api/*`

## 📈 Auto-Scaling Configuration

### Frontend HPA
- **Min Replicas**: 1
- **Max Replicas**: 5
- **CPU Target**: 50%
- **Memory Target**: 50%

### Backend HPA
- **Min Replicas**: 1
- **Max Replicas**: 3
- **CPU Target**: 70%
- **Memory Target**: 70%

## 🛡️ Security & Health Checks

### Backend Probes
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3001
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 3001
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Resource Limits
**Frontend:**
- CPU: 100m-500m
- Memory: 128Mi-512Mi

**Backend:**
- CPU: 100m-300m  
- Memory: 128Mi-256Mi

## 🚨 Troubleshooting

### Common Issues

1. **Backend Pod CrashLoopBackOff**
   ```bash
   kubectl logs -l app=kudos-backend
   # Check if Node.js dependencies are installed
   ```

2. **Frontend Can't Reach Backend**
   ```bash
   kubectl get svc kudos-backend
   # Ensure service is running and accessible
   ```

3. **LoadBalancer Pending**
   ```bash
   kubectl describe svc kudos-frontend
   # Check AWS ELB creation status
   ```

### Debug Commands
```bash
# Check all resources
kubectl get all

# Describe failing pods
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Port forward for debugging
kubectl port-forward svc/kudos-backend 3001:3001
kubectl port-forward svc/kudos-frontend 8080:80
```

## 🎯 Next Steps

1. **Database Integration**: Replace in-memory storage with persistent database
2. **SSL/TLS**: Add certificate management for HTTPS
3. **Monitoring**: Add Prometheus/Grafana for metrics
4. **Logging**: Centralized logging with ELK stack
5. **Secrets Management**: Use Kubernetes secrets for sensitive data

## 🔄 Rollback Procedure

If deployment fails, rollback using:
```bash
# Rollback frontend
kubectl rollout undo deployment/kudos-frontend

# Rollback backend  
kubectl rollout undo deployment/kudos-backend

# Check rollout status
kubectl rollout status deployment/kudos-frontend
kubectl rollout status deployment/kudos-backend
```

---

**🎉 Your full-stack Kudos app is now ready for production on Kubernetes!**