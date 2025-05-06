terraform {
  required_version = ">= 1.9.1"

  # backend "s3" {
  #   bucket         = "tfstate-your-org-prod"
  #   key            = "org-trail-to-splunk/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "tfstate-lock"
  #   encrypt        = true
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.97.0"
    }
  }
}

