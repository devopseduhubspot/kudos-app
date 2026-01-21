# Container Registry - This stores your application images
# Think of this as a place to store your packaged app

# Create a private repository for your Docker images
resource "aws_ecr_repository" "app" {
  name         = var.app_name
  force_delete = true  # Allow deletion even with images

  tags = {
    Name = "${var.app_name}-repository"
  }
}