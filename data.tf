# Data that must be gathered from AWS for the deployment to work.
data "aws_availability_zones" "available" {
  state = "available"
}

##############################################################################
# EC2
##############################################################################

# Get the latest non-beta RHEL 8 image in AWS provided by Cloud Access.
data "aws_ami" "rhel8_latest" {
  executable_users = ["self"]
  most_recent      = true
  # Exclude any beta images.
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
}

##############################################################################
# IAM
##############################################################################

# Get the policy from IAM that allows viewing everything.
data "aws_iam_policy" "viewonly" {
  arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

# Get the policy that allows reading IAM information.
data "aws_iam_policy" "read_only_iam" {
  arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

# Get the policy that allows reading CodeBuild information.
data "aws_iam_policy" "read_only_codebuild" {
  arn = "arn:aws:iam::aws:policy/AWSCodeBuildReadOnlyAccess"
}

# Allow Terraform to read state from S3.
data "aws_iam_policy_document" "terraform_read_state" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::imagebuilder-terraform-state",
      "arn:aws:s3:::imagebuilder-terraform-state/*"
    ]
  }
}

# Allow Terraform to use dynamodb for locking.
data "aws_iam_policy_document" "terraform_locks" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]

    resources = [
      "arn:aws:dynamodb:*:*:table/imagebuilder-terraform-locks",
    ]
  }
}

##############################################################################
# VPC
##############################################################################

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
