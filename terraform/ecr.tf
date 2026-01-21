# Container Registry - This stores your application images
# Think of this as a place to store your packaged app

# Create a private repository for your Docker images (Frontend)
resource "aws_ecr_repository" "app" {
  name         = var.app_name
  force_delete = true  # Allow deletion even with images

  tags = {
    Name = "${var.app_name}-frontend-repository"
  }

  lifecycle {
    # Prevent destruction if repository has images
    prevent_destroy = false
    # Ignore changes to tags that might be managed externally
    ignore_changes = [
      image_scanning_configuration,
    ]
  }
}

# Create a private repository for backend images  
resource "aws_ecr_repository" "backend" {
  name         = "${var.app_name}-backend"
  force_delete = true  # Allow deletion even with images

  tags = {
    Name = "${var.app_name}-backend-repository"
  }

  lifecycle {
    # Prevent destruction if repository has images
    prevent_destroy = false
    # Ignore changes to tags that might be managed externally
    ignore_changes = [
      image_scanning_configuration,
    ]
  }
}