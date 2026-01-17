#!/bin/bash
# ==============================================================================
# USER DATA SCRIPT FOR EC2 INSTANCES
# ==============================================================================
# This script runs when each EC2 instance starts up
# It prepares the server for Ansible configuration management
# ==============================================================================

# Update system packages
yum update -y

# Install required packages
yum install -y \
    git \
    curl \
    wget \
    unzip \
    python3 \
    python3-pip \
    htop \
    tree

# Install Node.js 18.x (required for the app)
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install nginx (will be configured by Ansible)
yum install -y nginx

# Install PM2 globally for process management
npm install -g pm2

# Create application directory
mkdir -p /opt/${app_name}
chown ec2-user:ec2-user /opt/${app_name}

# Create systemd service for the app (Ansible will populate this)
cat > /etc/systemd/system/${app_name}.service << EOF
[Unit]
Description=${app_name} Node.js App
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/${app_name}
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=${app_port}

[Install]
WantedBy=multi-user.target
EOF

# Enable and start nginx (Ansible will configure it)
systemctl enable nginx
systemctl start nginx

# Create log directory
mkdir -p /var/log/${app_name}
chown ec2-user:ec2-user /var/log/${app_name}

# Set up basic firewall rules
yum install -y iptables-services

# Create a simple motd for Ansible identification
cat > /etc/motd << EOF

========================================
  ${app_name} Web Server
========================================
Environment: Production
Managed by: Ansible
Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)
Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
========================================

EOF

# Install CloudWatch agent (for monitoring)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm
rm amazon-cloudwatch-agent.rpm

# Set up log rotation
cat > /etc/logrotate.d/${app_name} << EOF
/var/log/${app_name}/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 644 ec2-user ec2-user
    postrotate
        systemctl reload ${app_name} > /dev/null 2>&1 || true
    endscript
}
EOF

# Create Ansible facts directory
mkdir -p /etc/ansible/facts.d

# Create custom fact file
cat > /etc/ansible/facts.d/app.fact << EOF
[app]
name=${app_name}
port=${app_port}
environment=production
managed_by=ansible
setup_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# Signal that user data is complete
/opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackName} --resource AutoScalingGroup --region ${AWS::Region} || echo "CloudFormation signal failed (this is normal for Terraform)"

# Log completion
echo "$(date): User data script completed successfully" >> /var/log/user-data.log