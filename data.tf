# Data that must be gathered from AWS for the deployment to work.

##############################################################################
## GENERAL
# Get our current AWS region.
data "aws_region" "current" {}

data "aws_caller_identity" "identity" {}

# Get the availability zones in our region.
data "aws_availability_zones" "available" {
  state = "available"
}

# Get data for the account.
data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret" "gcp_service_account_image_builder" {
  name = "gcp_service_account_image_builder"
}
data "aws_secretsmanager_secret" "azure_account_image_builder" {
  name = "azure_account_image_builder"
}
data "aws_secretsmanager_secret" "aws_account_image_builder" {
  name = "aws_account_image_builder"
}
data "aws_secretsmanager_secret" "fedora_koji" {
  name = local.workspace_name == "staging" ? "fedora_koji_staging" : "fedora_koji_stable"
}
data "aws_secretsmanager_secret" "subscription_manager_command" {
  name = "subscription-manager-command"
}
data "aws_secretsmanager_secret" "offline_token" {
  name = "offline_token"
}
data "aws_secretsmanager_secret" "offline_token_fedora" {
  name = local.workspace_name == "staging" ? "offline_token_fedora_staging" : "offline_token_fedora_stable"
}
data "aws_secretsmanager_secret" "pozorbot" {
  name = "pozorbot"
}
data "aws_secretsmanager_secret" "schutzbot_gitlab_runner" {
  name = "schutzbot_gitlab_runner"
}

##############################################################################
## EC2
# Get the RHEL 8 image in AWS that we will use (provided by Cloud Access).
data "aws_ami" "rhel8_x86" {
  # Only images we can actually execute.
  executable_users = ["self"]
  # Restrict to RHEL8 GA images.
  name_regex = "^RHEL-8[.0-9]+_HVM-[0-9]{8}.*$"
  # Red Had Cloud Access account.
  owners = ["309956199498"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # This uniquely specifies the image, the other filters are
  # just sanity checks.
  filter {
    name   = "image-id"
    values = ["ami-0c82f7789103a1e20"]
  }
}

# Get the RHEL 8 image with osbuild-composer pre-installed that was created
# by packer.
data "aws_ami" "rhel8_x86_prebuilt" {
  owners      = ["self", "920877988636"]
  most_recent = true

  # Get the image that matches our composer_commit.
  filter {
    name   = "name"
    values = ["osbuild-composer-worker-main-${var.composer_commit}"]
  }
}

##############################################################################
## VPC
# Find the details for the internal VPC at AWS.
data "aws_vpc" "internal_vpc" {
  filter {
    name = "tag:Name"

    values = [
      "RD-Platform-Prod-US-East-1"
    ]
  }
}

# These deployments should use the old subnets so let's filter for them
data "aws_subnet" "internalA" {
  filter {
    name   = "tag:Name"
    values = ["InternalA"]
  }
}

data "aws_subnet" "internalB" {
  filter {
    name   = "tag:Name"
    values = ["InternalB"]
  }
}

data "aws_subnets" "internal_subnets" {
  filter {
    name = "subnet-id"
    values = [
      data.aws_subnet.internalA.id,
      data.aws_subnet.internalB.id,
    ]
  }
}

# Find all of the subnet details from the internal VPC.
data "aws_subnet" "internal_subnet_primary" {
  id = sort(data.aws_subnets.internal_subnets.ids)[0]
}

# Find the default VPC (not internal).
data "aws_vpc" "external_vpc" {
  default = true
}

# Find all of the subnet IDs from the default VPC.
data "aws_subnet_ids" "external_subnets" {
  vpc_id = data.aws_vpc.external_vpc.id
}

# Find all of the subnet details from the external VPC.
data "aws_subnet" "external_subnet_primary" {
  id = sort(data.aws_subnet_ids.external_subnets.ids)[0]
}
