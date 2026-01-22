# Variables - These are settings you can change easily
# Think of these as the "settings" for your infrastructure

# Basic Settings
variable "app_name" {
  description = "Name of your application"
  type        = string
  default     = "kudos-app"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# That's it! We keep it simple with just two main variables