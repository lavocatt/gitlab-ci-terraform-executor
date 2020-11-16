# Data that must be gathered from AWS for the deployment to work.

##############################################################################
## GENERAL
# Get the availability zones in our region.
data "aws_availability_zones" "available" {
  state = "available"
}

# Get data for the account.
data "aws_caller_identity" "current" {}

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

# Find all of the subnet IDs from the internal VPC.
data "aws_subnet_ids" "internal_subnets" {
  vpc_id = data.aws_vpc.internal_vpc.id
}

# Find the default VPC (not internal).
data "aws_vpc" "external_vpc" {
  default = true
}

# Find all of the subnet IDs from the default VPC.
data "aws_subnet_ids" "external_subnets" {
  vpc_id = data.aws_vpc.external_vpc.id
}
