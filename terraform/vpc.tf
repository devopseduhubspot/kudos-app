# Network Setup - This creates your private cloud network
# Think of this as setting up your own private internet in AWS

# 1. Create a Virtual Private Cloud (VPC) - Your private network space
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"  # This is like your network address
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.app_name}-vpc"  # Give it a nice name
    "kubernetes.io/cluster/${var.app_name}" = "shared"
  }
}

# 2. Create an Internet Gateway - This lets your network talk to the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-internet-gateway"
  }
}

# 3. Create Public Subnets - These can access the internet directly
resource "aws_subnet" "public" {
  count = 2  # Create 2 subnets in different AZs (required by EKS)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"  # Network addresses
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true  # Give resources public IPs

  tags = {
    Name = "${var.app_name}-public-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.app_name}" = "shared"
    "kubernetes.io/role/elb" = "1"  # Tell EKS this is for load balancers
  }
}

# 4. Create Route Table - This is like a GPS for network traffic
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"  # Send all traffic...
    gateway_id = aws_internet_gateway.main.id  # ...to the internet gateway
  }

  tags = {
    Name = "${var.app_name}-public-routes"
  }
}

# 5. Connect the public subnets to the route table
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}