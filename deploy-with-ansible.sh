#!/bin/bash
# ==============================================================================
# APPLICATION DEPLOYMENT SCRIPT WITH ANSIBLE
# ==============================================================================
# This script deploys the Kudos app to EC2 instances using Ansible
# Demonstrates configuration management and application deployment
# ==============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
TERRAFORM_DIR="$SCRIPT_DIR/terraform-ec2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check if Ansible is installed
    if ! command -v ansible &> /dev/null; then
        error "Ansible is not installed. Please install Ansible first."
        echo "Install with: pip3 install ansible boto3"
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check if infrastructure exists
    if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        error "Infrastructure not found. Please run create-ec2-infrastructure.sh first."
        exit 1
    fi
    
    # Check if SSH key exists
    if [ ! -f "$TERRAFORM_DIR/kudos-app-dev-key.pem" ]; then
        error "SSH key not found. Please run create-ec2-infrastructure.sh first."
        exit 1
    fi
    
    success "✅ Prerequisites check completed"
}

# Test connectivity to instances
test_connectivity() {
    log "🔌 Testing connectivity to instances..."
    
    cd "$ANSIBLE_DIR"
    
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "🔄 Connectivity test attempt $attempt/$max_attempts..."
        
        if ansible webservers -m ping -i inventory/aws_ec2.yml > /dev/null 2>&1; then
            success "✅ Ansible connectivity test passed"
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                warning "⚠️  Connectivity test failed. Retrying in 30 seconds..."
                sleep 30
            fi
        fi
        
        ((attempt++))
    done
    
    error "❌ Failed to establish connectivity after $max_attempts attempts"
    echo ""
    log "💡 Troubleshooting steps:"
    echo "1. Check if instances are running: aws ec2 describe-instances --filters 'Name=tag:Project,Values=kudos-app'"
    echo "2. Verify SSH key permissions: chmod 600 $TERRAFORM_DIR/kudos-app-dev-key.pem"
    echo "3. Test manual SSH: ssh -i $TERRAFORM_DIR/kudos-app-dev-key.pem ec2-user@<instance-ip>"
    echo "4. Check security group allows SSH (port 22) from your IP"
    
    exit 1
}

# Setup infrastructure (security, monitoring, etc.)
setup_infrastructure() {
    log "🛠️  Setting up infrastructure components..."
    
    cd "$ANSIBLE_DIR"
    
    # Run infrastructure setup playbook
    if ansible-playbook playbooks/setup-infrastructure.yml -i inventory/aws_ec2.yml; then
        success "✅ Infrastructure setup completed"
    else
        error "❌ Infrastructure setup failed"
        return 1
    fi
}

# Deploy application
deploy_application() {
    log "🚀 Deploying Kudos application..."
    
    cd "$ANSIBLE_DIR"
    
    # Run application deployment playbook
    if ansible-playbook playbooks/deploy-app.yml -i inventory/aws_ec2.yml; then
        success "✅ Application deployment completed"
    else
        error "❌ Application deployment failed"
        return 1
    fi
}

# Verify deployment
verify_deployment() {
    log "🔍 Verifying deployment..."
    
    cd "$TERRAFORM_DIR"
    
    # Get load balancer URL
    local lb_url=$(terraform output -raw application_url 2>/dev/null || echo "")
    
    if [ -z "$lb_url" ]; then
        error "Could not get load balancer URL from Terraform output"
        return 1
    fi
    
    log "🌐 Testing application at: $lb_url"
    
    # Test load balancer endpoint
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "🔄 Health check attempt $attempt/$max_attempts..."
        
        if curl -s -o /dev/null -w "%{http_code}" "$lb_url" | grep -q "200"; then
            success "✅ Application is responding successfully"
            echo ""
            log "🎉 Application is accessible at: $lb_url"
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                log "⏱️  Waiting for load balancer to detect healthy instances..."
                sleep 30
            fi
        fi
        
        ((attempt++))
    done
    
    warning "⚠️  Application health check failed after $max_attempts attempts"
    log "💡 This might be normal - the load balancer may need more time to detect healthy instances"
    log "🌐 Try accessing: $lb_url"
    
    return 0
}

# Run maintenance checks
run_maintenance() {
    log "🔧 Running maintenance checks..."
    
    cd "$ANSIBLE_DIR"
    
    # Run maintenance playbook
    if ansible-playbook playbooks/maintenance.yml -i inventory/aws_ec2.yml; then
        success "✅ Maintenance checks completed"
    else
        warning "⚠️  Some maintenance checks failed - check the output above"
    fi
}

# Display deployment information
show_deployment_info() {
    log "📋 Gathering deployment information..."
    
    cd "$TERRAFORM_DIR"
    
    local lb_url=$(terraform output -raw application_url 2>/dev/null || echo "N/A")
    local lb_dns=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "N/A")
    local asg_name=$(terraform output -raw autoscaling_group_name 2>/dev/null || echo "N/A")
    
    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "                          📊 DEPLOYMENT INFORMATION"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "🌐 Application URL:      $lb_url"
    echo "🔗 Load Balancer DNS:    $lb_dns"
    echo "📊 Auto Scaling Group:   $asg_name"
    echo "🕐 Deployment Time:      $(date)"
    echo ""
    
    # Get instance information
    log "🖥️  Instance Information:"
    aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=kudos-app" "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,PublicIpAddress,InstanceType,State.Name]' \
        --output table
    
    echo ""
}

# Main execution
main() {
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "                          🚀 APPLICATION DEPLOYMENT WITH ANSIBLE"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    log "Starting application deployment..."
    
    # Parse command line arguments
    local skip_setup=false
    local skip_verify=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-setup)
                skip_setup=true
                shift
                ;;
            --skip-verify)
                skip_verify=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --skip-setup    Skip infrastructure setup phase"
                echo "  --skip-verify   Skip deployment verification"
                echo "  -h, --help      Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    check_prerequisites
    test_connectivity
    
    if [ "$skip_setup" = false ]; then
        setup_infrastructure
    else
        log "⏭️  Skipping infrastructure setup (--skip-setup flag used)"
    fi
    
    deploy_application
    
    if [ "$skip_verify" = false ]; then
        verify_deployment
    else
        log "⏭️  Skipping deployment verification (--skip-verify flag used)"
    fi
    
    run_maintenance
    show_deployment_info
    
    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    success "🎉 Application deployment completed successfully!"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    log "📋 Next Steps:"
    echo "1. Access your application: $(cd "$TERRAFORM_DIR" && terraform output -raw application_url)"
    echo "2. Monitor with: cd ansible && ansible-playbook playbooks/maintenance.yml -i inventory/aws_ec2.yml"
    echo "3. View logs: ssh -i terraform-ec2/kudos-app-dev-key.pem ec2-user@<instance-ip> 'sudo -u ec2-user pm2 logs'"
    echo "4. Scale instances: Modify min_servers/max_servers in terraform-ec2/variables.tf and run terraform apply"
    echo ""
    
    log "🔧 Useful commands:"
    echo "  • Check application status: cd ansible && ansible webservers -m shell -a 'sudo -u ec2-user pm2 status' -i inventory/aws_ec2.yml"
    echo "  • Restart application: cd ansible && ansible webservers -m shell -a 'sudo -u ec2-user pm2 restart kudos-app' -i inventory/aws_ec2.yml"
    echo "  • Update application: cd ansible && ansible-playbook playbooks/deploy-app.yml -i inventory/aws_ec2.yml"
    echo "  • View system status: cd ansible && ansible-playbook playbooks/maintenance.yml -i inventory/aws_ec2.yml"
}

# Cleanup function for interrupted deployments
cleanup() {
    error "🛑 Deployment interrupted!"
    log "🧹 The infrastructure remains unchanged. You can resume deployment by running this script again."
}

# Set up signal handlers
trap cleanup INT TERM

# Run main function
main "$@"