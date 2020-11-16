##############################################################################
## AWS VM IMPORT REQUIREMENTS
# NOTE(mhayden): Much of this policy comes from the AWS docs for vmimport:
# https://docs.aws.amazon.com/vm-import/latest/userguide/vmie_prereqs.html

# Create vmimport trust policy.
data "aws_iam_policy_document" "vmimport_trust" {
  statement {
    sid = "1"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vmie.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "sts:Externalid"
      values   = ["vmimport"]
    }

  }
}

# Create base policy for vmimport with S3 storage.
data "aws_iam_policy_document" "vmimport_s3" {
  statement {
    sid = "1"

    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::imagebuilder-stage",
      "arn:aws:s3:::imagebuilder-stage/*",
      "arn:aws:s3:::imagebuilder-prod",
      "arn:aws:s3:::imagebuilder-prod/*"
    ]
  }
}

# Create base policy for vmimport with EC2.
data "aws_iam_policy_document" "vmimport_ec2" {
  statement {
    sid = "1"

    actions = [
      "ec2:ModifySnapshotAttribute",
      "ec2:CopySnapshot",
      "ec2:RegisterImage",
      "ec2:Describe*"
    ]

    resources = ["*"]
  }
}

# Load the vmimport S3/EC2 policies
resource "aws_iam_policy" "vmimport_s3" {
  name   = "vmimport_s3"
  policy = data.aws_iam_policy_document.vmimport_s3.json
}
resource "aws_iam_policy" "vmimport_ec2" {
  name   = "vmimport_ec2"
  policy = data.aws_iam_policy_document.vmimport_ec2.json
}

# Create the vmimport role.
resource "aws_iam_role" "vmimport" {
  name               = "vmimport"
  assume_role_policy = data.aws_iam_policy_document.vmimport_trust.json

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder vmimport role" },
  )
}

# Attach base vmimport policy to role.
resource "aws_iam_role_policy_attachment" "vmimport_s3" {
  role       = aws_iam_role.vmimport.name
  policy_arn = aws_iam_policy.vmimport_s3.arn
}
resource "aws_iam_role_policy_attachment" "vmimport_ec2" {
  role       = aws_iam_role.vmimport.name
  policy_arn = aws_iam_policy.vmimport_ec2.arn
}

##############################################################################
## STAGE
# Create S3 bucket for stage workers to upload images.
resource "aws_s3_bucket" "imagebuilder_stage" {
  bucket = "imagebuilder-service-stage"
  acl    = "private"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder S3 bucket for Stage" },
  )
}

# Generate policy to allow workers to upload images to S3.
data "aws_iam_policy_document" "imagebuilder_stage" {
  statement {
    sid = "1"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:aws:s3:::imagebuilder-stage",
      "arn:aws:s3:::imagebuilder-stage/*"
    ]
  }
}

# Create policy based on s3 upload policy document.
resource "aws_iam_policy" "imagebuilder_stage_workers_s3" {
  name   = "imagebuilder-stage-workers-s3"
  policy = data.aws_iam_policy_document.imagebuilder_stage.json
}

# Create the stage IAM user.
resource "aws_iam_user" "imagebuilder_stage" {
  name = "imagebuilder-stage"
  path = "/workers/"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder Stage User" },
  )
}

# Attach policies.
resource "aws_iam_user_policy_attachment" "imagebuilder_stage_s3" {
  user       = aws_iam_user.imagebuilder_stage.name
  policy_arn = aws_iam_policy.imagebuilder_stage_workers_s3.arn
}
resource "aws_iam_user_policy_attachment" "imagebuilder_stage_vmimport" {
  user       = aws_iam_user.imagebuilder_stage.name
  policy_arn = aws_iam_policy.vmimport_ec2.arn
}

##############################################################################
## PROD
# Create S3 bucket for prod workers to upload images.
resource "aws_s3_bucket" "imagebuilder_prod" {
  bucket = "imagebuilder-service-prod"
  acl    = "private"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder S3 bucket for Prod" },
  )
}

# Policy to allow workers to upload images to S3.
data "aws_iam_policy_document" "imagebuilder_prod" {
  statement {
    sid = "1"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:aws:s3:::imagebuilder-prod",
      "arn:aws:s3:::imagebuilder-prod/*"
    ]
  }
}

# Create policy based on s3 upload policy document.
resource "aws_iam_policy" "imagebuilder_prod_workers_s3" {
  name   = "imagebuilder-prod-workers-s3"
  policy = data.aws_iam_policy_document.imagebuilder_prod.json
}

# Create the prod IAM user.
resource "aws_iam_user" "imagebuilder_prod" {
  name = "imagebuilder-prod"
  path = "/workers/"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder Prod User" },
  )
}

# Attach policies.
resource "aws_iam_user_policy_attachment" "imagebuilder_prod_s3" {
  user       = aws_iam_user.imagebuilder_prod.name
  policy_arn = aws_iam_policy.imagebuilder_prod_workers_s3.arn
}
resource "aws_iam_user_policy_attachment" "imagebuilder_prod_vmimport" {
  user       = aws_iam_user.imagebuilder_prod.name
  policy_arn = aws_iam_policy.vmimport_ec2.arn
}
