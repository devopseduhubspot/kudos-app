# Terraform Backend Configuration
# This stores your Terraform state in AWS S3 for safe keeping and team collaboration

terraform {
  backend "s3" {
    # These values will be provided via init command in GitHub Actions
    # bucket = "your-terraform-state-bucket"
    # key    = "kudos-app/dev/terraform.tfstate" 
    # region = "us-east-1"
    
    # Enable state locking and consistency checking via DynamoDB
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}