##############################################################################
## BASE TERRAFORM CONFIGURATION
# NOTE(mhayden): Making changes here can cause some serious problems. Use
# caution before changing anything here.
terraform {

  # Exit with an error if someone is running old terraform.
  required_version = ">= 0.13.5"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    null = {
      source = "hashicorp/null"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  # We use Terraform Cloud to manage our deployments.
  # https://app.terraform.io/app/imagebuilder/workspaces
  backend "remote" {
    organization = "imagebuilder"

    workspaces {
      prefix = "imagebuilder-"
    }
  }
}
