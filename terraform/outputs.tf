# Outputs - These show important information after deployment
# Think of these as the "results" you get after everything is built

output "cluster_name" {
  description = "Name of your EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "ecr_repository_url" {
  description = "Where your Docker images are stored"
  value       = aws_ecr_repository.app.repository_url
}

output "vpc_id" {
  description = "ID of your private network"
  value       = aws_vpc.main.id
}

output "how_to_connect" {
  description = "Command to connect to your cluster"
  value       = "aws eks --region us-east-1 update-kubeconfig --name ${aws_eks_cluster.main.name}"
}