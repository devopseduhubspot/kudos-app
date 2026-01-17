# EKS Cluster - This creates your Kubernetes cluster
# Think of this as creating a computer that can run many applications

# 1. Create a role for the EKS cluster (permission to work in AWS)
resource "aws_iam_role" "eks_cluster" {
  name = "${var.app_name}-cluster-role"

  # This says "EKS service can use this role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# 2. Give the cluster role the permissions it needs
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# 3. Create the actual EKS cluster
resource "aws_eks_cluster" "main" {
  name     = var.app_name
  role_arn = aws_iam_role.eks_cluster.arn

  # Tell it which network to use
  vpc_config {
    subnet_ids = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
  }

  # Wait for the role to be ready
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = {
    Name = "${var.app_name}-cluster"
  }
}

# 4. Create a role for the worker nodes (the computers that run your apps)
resource "aws_iam_role" "eks_nodes" {
  name = "${var.app_name}-node-role"

  # This says "EC2 service can use this role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 5. Give the worker nodes all the permissions they need
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# 6. Create the worker nodes (the actual computers)
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.app_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id  # Put them in private subnets for security

  # Configure the computers
  instance_types = ["t3.medium"]  # Medium-sized computers (2 CPU, 4GB RAM)

  # How many computers do we want?
  scaling_config {
    desired_size = 2  # We want 2 computers
    max_size     = 3  # Never more than 3
    min_size     = 1  # At least 1
  }

  # Wait for all the permissions to be ready
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name = "${var.app_name}-nodes"
  }
}