# Terraform Backend Configuration
# This stores your Terraform state in AWS S3 for safe keeping and team collaboration

terraform {
  backend "s3" {
    # S3 bucket configuration
    bucket = "make_bucket: terraform-state-kudos-app-1267304863 terraform-state-kudos-app-1267304863"
    key    = "kudos-app/dev/terraform.tfstate" 
    region = "us-east-1"
    
    # Enable state locking and consistency checking via DynamoDB
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}




