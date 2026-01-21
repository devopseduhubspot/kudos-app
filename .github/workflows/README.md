# 🚀 CI/CD Pipeline Documentation

## Overview

This CI/CD pipeline provides a comprehensive, enterprise-grade deployment workflow for the Kudos App to AWS EKS (Elastic Kubernetes Service).

## 🔄 Workflow Stages

### 1. **📦 Install Dependencies**
- Installs npm dependencies with caching
- Uses Node.js 18 LTS

### 2. **🔍 Lint**
- Runs ESLint for code quality checks
- Ensures code standards compliance

### 3. **🧪 Test**
- Executes unit tests with Vitest
- Runs in CI mode for optimal performance

### 4. **🛡️ Security Scan**
- Snyk vulnerability scanning for dependencies
- Fails on high-severity vulnerabilities
- Sends reports to Snyk dashboard

### 5. **🏗️ Build**
- Creates optimized production build
- Validates build artifacts

### 6. **🐳 Build & Push to ECR**
- Builds Docker image with multi-stage optimization
- Pushes to AWS ECR with SHA and latest tags
- Performs Trivy security scan on container image
- Uploads security findings to GitHub Security tab

### 7. **☸️ Deploy to AWS EKS**
- Deploys to specified environment (dev/staging/prod)
- Updates Kubernetes manifests with new image tags
- Performs rolling deployment with health checks
- Validates application accessibility

### 8. **📋 Post-Deployment Validation**
- Generates deployment reports
- Sends success/failure notifications
- Collects deployment metrics

## 🔐 Required GitHub Secrets

Configure the following secrets in your GitHub repository settings:

### AWS Credentials
```
AWS_ACCESS_KEY_ID          # AWS Access Key ID for ECR/EKS access
AWS_SECRET_ACCESS_KEY      # AWS Secret Access Key
ECR_REGISTRY              # ECR registry URL (e.g., 036983629554.dkr.ecr.us-east-1.amazonaws.com)
```

### Security Scanning
```
SNYK_TOKEN                # Snyk API token for vulnerability scanning
```

## 🎯 Environment Configuration

The pipeline supports multiple deployment environments:

- **dev**: Development environment
- **staging**: Pre-production testing
- **prod**: Production environment

## 🚀 How to Deploy

### Manual Deployment
1. Go to **Actions** tab in GitHub
2. Select **main-ci-cd-manual** workflow
3. Click **Run workflow**
4. Select target environment (dev/staging/prod)
5. Click **Run workflow**

### Environment Promotion
```bash
# Deploy to dev first
Environment: dev → Test & Validate

# Promote to staging
Environment: staging → Final testing

# Deploy to production
Environment: prod → Live deployment
```

## 📊 Pipeline Features

### ✅ **Quality Gates**
- Code linting and formatting
- Unit test coverage
- Security vulnerability scanning
- Container image security scanning

### 🔍 **Monitoring & Validation**
- Application health checks
- Kubernetes deployment validation
- HTTP endpoint testing
- Resource monitoring

### 📈 **Reporting**
- Deployment status reports
- Security scan results
- Performance metrics
- Failure notifications

## 🛠️ Infrastructure Requirements

### AWS Resources
- **EKS Cluster**: `kudos-app-cluster`
- **ECR Repository**: `kudos-app`
- **IAM Roles**: Proper permissions for EKS/ECR access

### Kubernetes Manifests
- Deployment configuration in `k8s/deployment.yaml`
- Service and Ingress configurations
- Resource limits and health checks

## 🔧 Troubleshooting

### Common Issues

1. **ECR Authentication Errors**
   - Verify AWS credentials have ECR permissions
   - Check ECR repository exists and has correct name

2. **EKS Connection Issues**
   - Ensure EKS cluster is running
   - Verify kubectl has proper permissions
   - Check cluster name matches configuration

3. **Deployment Failures**
   - Review pod logs: `kubectl logs deployment/kudos-frontend`
   - Check resource limits and requests
   - Verify image pull secrets if using private registry

### Debug Commands
```bash
# Check deployment status
kubectl get deployments

# View pod details
kubectl get pods -l app=kudos-frontend

# Check service configuration
kubectl get services

# View recent events
kubectl get events --sort-by='.lastTimestamp'
```

## 🎖️ Best Practices

### Security
- ✅ Image vulnerability scanning
- ✅ Dependency security checks
- ✅ Container hardening
- ✅ Minimal base images

### Performance
- ✅ Multi-stage Docker builds
- ✅ Resource limits and requests
- ✅ Health checks and readiness probes
- ✅ Horizontal pod autoscaling support

### Reliability
- ✅ Rolling deployments
- ✅ Deployment validation
- ✅ Automated rollback capability
- ✅ Comprehensive monitoring

## 📞 Support

For issues with the CI/CD pipeline:
1. Check the **Actions** tab for detailed logs
2. Review this documentation
3. Verify all required secrets are configured
4. Ensure AWS infrastructure is properly set up