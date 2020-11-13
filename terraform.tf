# Base settings for terraform go here.

# NOTE(mhayden): Making changes here can cause some serious problems. Use
# caution before changing anything here.
terraform {
  # Exit with an error if someone is running old terraform.
  required_version = ">= 0.13.5"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  backend "remote" {
    organization = "imagebuilder"

    workspaces {
      name = "imagebuilder-deployment"
    }
  }
}
