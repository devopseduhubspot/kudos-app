# 🖥️ EC2 + Ansible Deployment Scenario

This scenario demonstrates **traditional server-based deployment** using **EC2 instances** and **Ansible configuration management**. It's perfect for teaching DevOps concepts and comparing traditional approaches with container orchestration.

## 🎯 **Learning Objectives**

This scenario teaches:
- **Infrastructure as Code** with Terraform
- **Configuration Management** with Ansible  
- **Traditional server deployment** vs containerization
- **Auto Scaling** and **Load Balancing**
- **Security hardening** and monitoring
- **CI/CD pipelines** with GitHub Actions
- **Operational procedures** and maintenance

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS CLOUD                               │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────────────────────────────┐    │
│  │    ALB      │    │             VPC                     │    │
│  │ (Port 80)   │────│  ┌─────────────┐ ┌─────────────┐   │    │
│  └─────────────┘    │  │EC2 Instance │ │EC2 Instance │   │    │
│                     │  │ (Web+App)   │ │ (Web+App)   │   │    │
│  ┌─────────────┐    │  │   - Nginx   │ │   - Nginx   │   │    │
│  │Auto Scaling │────│  │   - Node.js │ │   - Node.js │   │    │
│  │    Group    │    │  │   - PM2     │ │   - PM2     │   │    │
│  └─────────────┘    │  └─────────────┘ └─────────────┘   │    │
│                     │                                     │    │
│  ┌─────────────┐    │  ┌─────────────┐ ┌─────────────┐   │    │
│  │ CloudWatch  │────│  │  Logs &     │ │ Security    │   │    │
│  │ Monitoring  │    │  │ Monitoring  │ │ Groups      │   │    │
│  └─────────────┘    │  └─────────────┘ └─────────────┘   │    │
└─────────────────────────────────────────────────────────────────┘
                              │
                         Ansible Management
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    DevOps Workstation                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │
│  │  Terraform  │ │   Ansible   │ │   GitHub    │              │
│  │    (IaC)    │ │   (CM)      │ │  Actions    │              │
│  └─────────────┘ └─────────────┘ └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 **Project Structure**

```
kudos-app/
├── terraform-ec2/              # Infrastructure as Code
│   ├── main.tf                 # Provider and data sources
│   ├── variables.tf            # Input variables
│   ├── vpc.tf                  # Network infrastructure
│   ├── ec2.tf                  # EC2 instances and auto scaling
│   ├── load_balancer.tf        # Application Load Balancer
│   ├── user_data.sh            # EC2 initialization script
│   └── outputs.tf              # Infrastructure outputs
│
├── ansible/                    # Configuration Management
│   ├── ansible.cfg             # Ansible configuration
│   ├── inventory/              # Inventory management
│   │   ├── aws_ec2.yml         # Dynamic AWS inventory
│   │   └── static_hosts.ini    # Static inventory example
│   ├── playbooks/              # Automation playbooks
│   │   ├── deploy-app.yml      # Application deployment
│   │   ├── setup-infrastructure.yml # Infrastructure setup
│   │   └── maintenance.yml     # Maintenance and monitoring
│   └── roles/webapp/           # Reusable roles
│       └── templates/          # Configuration templates
│           ├── nginx.conf.j2   # Nginx configuration
│           ├── ecosystem.config.js.j2 # PM2 configuration  
│           ├── app.env.j2      # Application environment
│           └── deployment_report.txt.j2 # Reporting
│
├── scripts/                    # Deployment automation
│   ├── create-ec2-infrastructure.sh  # Infrastructure creation
│   └── deploy-with-ansible.sh       # Application deployment
│
├── .github/workflows/          # CI/CD Automation
│   └── deploy-ec2-ansible.yml  # GitHub Actions workflow
│
└── README-EC2-ANSIBLE.md       # This documentation
```

## 🚀 **Quick Start Guide**

### Option 1: Manual Deployment (Great for Learning)

```bash
# 1. Create infrastructure
chmod +x create-ec2-infrastructure.sh
./create-ec2-infrastructure.sh

# 2. Deploy application
chmod +x deploy-with-ansible.sh
./deploy-with-ansible.sh
```

### Option 2: GitHub Actions (Production-like CI/CD)

1. **Configure Secrets** in GitHub repository:
   ```
   AWS_ACCESS_KEY_ID=your-access-key
   AWS_SECRET_ACCESS_KEY=your-secret-key
   SLACK_WEBHOOK_URL=your-slack-webhook (optional)
   ```

2. **Trigger Deployment**:
   - Go to GitHub Actions tab
   - Select "Deploy to EC2 with Ansible"
   - Click "Run workflow" → Choose "deploy" → Run

3. **Monitor Progress** in GitHub Actions UI

## 🔧 **Detailed Setup Instructions**

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** installed (v1.7.0+)
4. **Ansible** installed (v8.0.0+)
5. **Git** for version control

### Step-by-Step Deployment

#### 1. Infrastructure Creation (Terraform)

```bash
cd terraform-ec2

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply
```

**What this creates:**
- ✅ VPC with public subnets
- ✅ Security groups (web servers + load balancer)
- ✅ Application Load Balancer
- ✅ Auto Scaling Group (2-4 instances)
- ✅ CloudWatch monitoring
- ✅ SSH key pair for access

#### 2. Configuration Management (Ansible)

```bash
cd ansible

# Test connectivity
ansible webservers -m ping -i inventory/aws_ec2.yml

# Setup infrastructure (security, monitoring)
ansible-playbook playbooks/setup-infrastructure.yml -i inventory/aws_ec2.yml

# Deploy application
ansible-playbook playbooks/deploy-app.yml -i inventory/aws_ec2.yml
```

**What Ansible configures:**
- ✅ System security (fail2ban, firewall)
- ✅ Performance optimization (swap, limits)
- ✅ Nginx reverse proxy
- ✅ Node.js application with PM2
- ✅ Monitoring and logging
- ✅ Health checks and reporting

#### 3. Verification

```bash
# Check application status
ansible webservers -m shell -a "sudo -u ec2-user pm2 status" -i inventory/aws_ec2.yml

# Run maintenance checks  
ansible-playbook playbooks/maintenance.yml -i inventory/aws_ec2.yml

# Access application
curl http://$(cd terraform-ec2 && terraform output -raw load_balancer_dns)
```

## 🎓 **DevOps Concepts Demonstrated**

### 1. Infrastructure as Code (IaC)
- **Tool**: Terraform
- **Benefits**: Version controlled, reproducible, documented
- **Files**: `terraform-ec2/*.tf`
- **Commands**: `terraform plan/apply/destroy`

### 2. Configuration Management (CM)  
- **Tool**: Ansible
- **Benefits**: Idempotent, agentless, declarative
- **Files**: `ansible/playbooks/*.yml`
- **Commands**: `ansible-playbook`

### 3. Immutable vs Mutable Infrastructure
- **Mutable**: EC2 instances updated in place
- **Process**: Ansible applies changes to existing servers
- **Contrast**: Compare with immutable container deployments

### 4. Traditional Deployment Patterns
- **Web Server**: Nginx as reverse proxy
- **App Server**: Node.js with PM2 process manager
- **Load Balancer**: AWS ALB for traffic distribution
- **Auto Scaling**: Horizontal scaling based on CPU

### 5. Security Hardening
- **Network**: VPC, subnets, security groups
- **Server**: fail2ban, firewall rules, SSH keys
- **Application**: Process isolation, least privilege

### 6. Monitoring & Logging
- **System**: CloudWatch agent, system metrics
- **Application**: PM2 process monitoring
- **Logs**: Centralized logging with rotation

### 7. CI/CD Pipeline
- **Trigger**: Git push or manual dispatch
- **Stages**: Infrastructure → Configuration → Deployment → Verification
- **Notifications**: Slack, GitHub issues, artifacts

## 🆚 **EC2+Ansible vs Kubernetes Comparison**

| Aspect | EC2 + Ansible | Kubernetes (EKS) |
|--------|---------------|------------------|
| **Complexity** | Medium | High |
| **Learning Curve** | Gentle | Steep |
| **Infrastructure** | Traditional servers | Container orchestration |
| **Scaling** | Auto Scaling Groups | Pod/Node autoscaling |
| **Deployment** | Server updates | Rolling updates |
| **Configuration** | Ansible playbooks | YAML manifests |
| **Service Discovery** | Load balancer | Built-in service mesh |
| **Rollbacks** | Ansible rollback | Kubernetes rollouts |
| **Monitoring** | Traditional tools | Cloud-native observability |
| **Cost** | Lower (fewer components) | Higher (control plane costs) |

## 🔄 **Operational Procedures**

### Daily Operations

```bash
# Check system health
ansible-playbook playbooks/maintenance.yml -i inventory/aws_ec2.yml

# Update application
git push origin main  # Triggers GitHub Actions

# Scale instances manually
# Edit terraform-ec2/variables.tf (min_servers, max_servers)
cd terraform-ec2 && terraform apply
```

### Troubleshooting

```bash
# SSH to instance
ssh -i terraform-ec2/kudos-app-dev-key.pem ec2-user@<instance-ip>

# Check application logs
sudo -u ec2-user pm2 logs kudos-app

# Check Nginx logs
sudo tail -f /var/log/nginx/kudos-app_error.log

# Restart application
sudo -u ec2-user pm2 restart kudos-app

# Check system resources
htop
df -h
free -m
```

### Disaster Recovery

```bash
# Full redeployment
terraform destroy  # Remove old infrastructure
terraform apply    # Create new infrastructure
./deploy-with-ansible.sh  # Redeploy application

# Application-only recovery
ansible-playbook playbooks/deploy-app.yml -i inventory/aws_ec2.yml
```

## 📊 **Cost Considerations**

### Estimated Monthly Costs (us-east-1)
- **2x t3.micro instances**: ~$16/month
- **Application Load Balancer**: ~$22/month  
- **Data transfer**: ~$5/month
- **CloudWatch**: ~$3/month
- **Total**: ~$46/month

### Cost Optimization Tips
1. Use **t3.micro** for development (free tier eligible)
2. **Stop instances** when not needed
3. Use **Spot instances** for non-critical workloads  
4. **Monitor usage** with AWS Cost Explorer
5. **Destroy infrastructure** after training sessions

## 🎯 **Teaching Benefits**

### Why This Scenario is Perfect for Teaching DevOps:

1. **Familiar Concepts**: Traditional servers are easier to understand
2. **Clear Progression**: Infrastructure → Configuration → Deployment  
3. **Visible Results**: Students can SSH and see traditional Linux processes
4. **Practical Skills**: Real-world server management techniques
5. **Comparison Ready**: Easy to contrast with containerized approaches
6. **Hands-on Learning**: Multiple tools and techniques in one scenario
7. **Scalable Complexity**: Start simple, add advanced concepts

### Suggested Teaching Sequence:

1. **Week 1**: Manual infrastructure with AWS Console
2. **Week 2**: Terraform for Infrastructure as Code
3. **Week 3**: Ansible basics with simple playbooks  
4. **Week 4**: Complete application deployment
5. **Week 5**: Monitoring, maintenance, and troubleshooting
6. **Week 6**: CI/CD with GitHub Actions
7. **Week 7**: Compare with Kubernetes approach

## 📚 **Additional Learning Resources**

- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws
- **Ansible Documentation**: https://docs.ansible.com/
- **AWS EC2 Best Practices**: https://aws.amazon.com/ec2/getting-started/
- **Nginx Configuration**: https://nginx.org/en/docs/
- **PM2 Process Manager**: https://pm2.keymetrics.io/docs/
- **AWS Auto Scaling**: https://aws.amazon.com/autoscaling/

## 💡 **Advanced Extensions**

Once comfortable with the basics, try these advanced scenarios:

1. **Multi-Environment**: Deploy dev/staging/prod environments
2. **Database Integration**: Add RDS database with Ansible configuration
3. **SSL Certificates**: Configure HTTPS with Let's Encrypt
4. **Blue-Green Deployment**: Implement zero-downtime deployments
5. **Monitoring Stack**: Add Prometheus/Grafana monitoring
6. **Log Aggregation**: Implement centralized logging with ELK stack
7. **Backup Automation**: Schedule and automate backups
8. **Disaster Recovery**: Implement cross-region disaster recovery

This scenario provides a solid foundation in traditional DevOps practices while preparing students for more advanced container orchestration concepts! 🚀