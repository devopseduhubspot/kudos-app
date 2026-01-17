#!/bin/bash
# ==============================================================================
# EC2 INFRASTRUCTURE DEPLOYMENT SCRIPT
# ==============================================================================
# This script creates AWS EC2 infrastructure using Terraform
# Perfect for demonstrating Infrastructure as Code concepts
# ==============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform-ec2"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

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
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed. Please install Terraform first."
        echo "Installation instructions: https://learn.hashicorp.com/terraform/getting-started/install"
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install AWS CLI first."
        echo "Installation instructions: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check if Ansible is installed
    if ! command -v ansible &> /dev/null; then
        warning "Ansible is not installed. You'll need it for application deployment."
        echo "Install with: pip3 install ansible boto3"
    fi
    
    success "✅ Prerequisites check completed"
}

# Initialize Terraform
init_terraform() {
    log "🚀 Initializing Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    terraform init
    
    # Validate configuration
    terraform validate
    
    success "✅ Terraform initialized successfully"
}

# Plan infrastructure changes
plan_infrastructure() {
    log "📋 Planning infrastructure changes..."
    
    cd "$TERRAFORM_DIR"
    
    # Create terraform plan
    terraform plan -out=tfplan
    
    echo ""
    log "📊 Infrastructure plan created successfully"
    echo ""
    
    # Ask for confirmation
    read -p "Do you want to apply these changes? (yes/no): " confirm
    if [[ $confirm != "yes" ]]; then
        warning "Deployment cancelled by user"
        exit 0
    fi
}

# Apply infrastructure changes
apply_infrastructure() {
    log "🏗️  Creating infrastructure..."
    
    cd "$TERRAFORM_DIR"
    
    # Apply the plan
    terraform apply tfplan
    
    if [ $? -eq 0 ]; then
        success "✅ Infrastructure created successfully!"
        
        # Save outputs
        terraform output > ../terraform-outputs.txt
        
        # Display important information
        echo ""
        log "📋 Important Information:"
        echo "────────────────────────────────────────────────────────"
        terraform output -json | jq -r '
            "🌐 Application URL: " + .application_url.value,
            "🔗 Load Balancer DNS: " + .load_balancer_dns.value,
            "🔑 SSH Key: " + .ssh_key_name.value,
            "🖥️  Instance Type: " + .instance_type.value,
            "📊 Auto Scaling Group: " + .autoscaling_group_name.value
        '
        echo "────────────────────────────────────────────────────────"
    else
        error "❌ Infrastructure deployment failed!"
        exit 1
    fi
}

# Generate Ansible inventory
generate_inventory() {
    log "📝 Generating Ansible inventory..."
    
    cd "$TERRAFORM_DIR"
    
    # Wait a moment for instances to be ready
    log "⏱️  Waiting for instances to be ready..."
    sleep 30
    
    # Get instance information
    local asg_name=$(terraform output -raw autoscaling_group_name)
    local region=$(terraform output -json infrastructure_summary | jq -r '.value.region')
    
    # Create dynamic inventory file
    cat > "$ANSIBLE_DIR/inventory/terraform_inventory.sh" << 'EOF'
#!/bin/bash
# Dynamic inventory script for Terraform-created instances

if [ "$1" = "--list" ]; then
    # Get instances from AWS
    aws ec2 describe-instances \
        --filters "Name=tag:AnsibleGroup,Values=webservers" \
                  "Name=instance-state-name,Values=running" \
        --query '{
            "webservers": {
                "hosts": Reservations[*].Instances[*].PublicIpAddress | [?@ != null],
                "vars": {
                    "ansible_user": "ec2-user",
                    "ansible_ssh_private_key_file": "../terraform-ec2/kudos-app-dev-key.pem",
                    "ansible_ssh_common_args": "-o StrictHostKeyChecking=no"
                }
            },
            "_meta": {
                "hostvars": {}
            }
        }' \
        --output json
elif [ "$1" = "--host" ]; then
    echo '{"_meta": {"hostvars": {}}}'
else
    echo "Usage: $0 --list or $0 --host <hostname>"
    exit 1
fi
EOF
    
    chmod +x "$ANSIBLE_DIR/inventory/terraform_inventory.sh"
    
    success "✅ Ansible inventory generated"
}

# Test connectivity
test_connectivity() {
    log "🔌 Testing connectivity to instances..."
    
    cd "$ANSIBLE_DIR"
    
    # Test Ansible connectivity
    if ansible webservers -m ping -i inventory/terraform_inventory.sh 2>/dev/null; then
        success "✅ Ansible connectivity test passed"
        return 0
    else
        warning "⚠️  Ansible connectivity test failed. Instances may still be starting up."
        log "💡 You can test connectivity later with:"
        echo "   cd $ANSIBLE_DIR"
        echo "   ansible webservers -m ping -i inventory/terraform_inventory.sh"
        return 1
    fi
}

# Main execution
main() {
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "                          🏗️  EC2 INFRASTRUCTURE DEPLOYMENT"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    log "Starting infrastructure deployment..."
    
    check_prerequisites
    init_terraform
    plan_infrastructure
    apply_infrastructure
    generate_inventory
    
    # Test connectivity (non-blocking)
    test_connectivity || true
    
    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    success "🎉 Infrastructure deployment completed successfully!"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    log "📋 Next Steps:"
    echo "1. Wait 2-3 minutes for instances to fully initialize"
    echo "2. Test Ansible connectivity: cd ansible && ansible webservers -m ping -i inventory/terraform_inventory.sh"
    echo "3. Deploy application: cd ansible && ansible-playbook playbooks/setup-infrastructure.yml"
    echo "4. Deploy app: cd ansible && ansible-playbook playbooks/deploy-app.yml"
    echo "5. Access your application at: $(cd "$TERRAFORM_DIR" && terraform output -raw application_url)"
    echo ""
    
    log "📁 Files created:"
    echo "  • terraform-outputs.txt - Infrastructure details"
    echo "  • ansible/inventory/terraform_inventory.sh - Dynamic inventory"
    echo "  • terraform-ec2/kudos-app-dev-key.pem - SSH private key"
    echo ""
    
    log "🔧 Useful commands:"
    echo "  • Check infrastructure: cd terraform-ec2 && terraform show"
    echo "  • Test connectivity: cd ansible && ansible webservers -m ping -i inventory/terraform_inventory.sh"
    echo "  • Deploy app: cd ansible && ansible-playbook playbooks/deploy-app.yml -i inventory/terraform_inventory.sh"
    echo "  • Destroy infrastructure: cd terraform-ec2 && terraform destroy"
}

# Cleanup function for interrupted deployments
cleanup() {
    error "🛑 Deployment interrupted!"
    log "🧹 Cleaning up..."
    
    cd "$TERRAFORM_DIR" 2>/dev/null || true
    
    if [ -f "tfplan" ]; then
        rm -f tfplan
        log "🗑️  Removed Terraform plan file"
    fi
}

# Set up signal handlers
trap cleanup INT TERM

# Run main function
main "$@"