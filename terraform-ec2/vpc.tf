# ==============================================================================
# VPC AND NETWORKING CONFIGURATION
# ==============================================================================
# Creates a Virtual Private Cloud with public and private subnets
# Demonstrates network isolation and security best practices
# ==============================================================================

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
    Type = "VPC"
  })
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
    Type = "InternetGateway"
  })
}

# Create public subnets for web servers
resource "aws_subnet" "public" {
  count = length(local.availability_zones)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Type = "PublicSubnet"
    AZ   = local.availability_zones[count.index]
  })
}

# Create route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    Type = "RouteTable"
  })
}

# Associate public subnets with route table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# SECURITY GROUPS
# ==============================================================================

# Security group for web servers
resource "aws_security_group" "web_servers" {
  name_prefix = "${local.name_prefix}-web-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for web servers running Kudos app"
  
  # HTTP access from load balancer
  ingress {
    description     = "HTTP from Load Balancer"
    from_port       = local.nginx_port
    to_port         = local.nginx_port
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }
  
  # Application port from load balancer
  ingress {
    description     = "App port from Load Balancer"
    from_port       = local.app_port
    to_port         = local.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }
  
  # SSH access for Ansible
  ingress {
    description = "SSH for Ansible management"
    from_port   = local.ssh_port
    to_port     = local.ssh_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }
  
  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-sg"
    Type = "SecurityGroup"
    Purpose = "WebServers"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# Security group for load balancer
resource "aws_security_group" "load_balancer" {
  name_prefix = "${local.name_prefix}-lb-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for application load balancer"
  
  # HTTP access from internet
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # HTTPS access from internet
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-lb-sg"
    Type = "SecurityGroup"
    Purpose = "LoadBalancer"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}