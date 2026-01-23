# Terraform Backend Configuration
# This stores your Terraform state in AWS S3 for safe keeping and team collaboration

terraform {
  backend "s3" {
    # S3 bucket configuration
    bucket = "terraform-state-kudos-app-1312929825"
    key    = "kudos-app/dev/terraform.tfstate" 
    region = "us-east-1"
    
    # Enable state locking and consistency checking via DynamoDB
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}





