terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.87.0"
    }
  }

  backend "s3" {
    bucket         = "opsfleet-tfstate-us-east-1"
    encrypt        = true
    region         = "us-east-1"
    dynamodb_table = "opsfleet-tfstate-lock"
    key            = "opsfleet/terraform.tfstate"
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = {
      Environment = var.environment
      Provisioner = "terraform"
      Owner       = var.team
      SourcePath  = var.project_repo
      Project     = var.project
    }
  }
}
