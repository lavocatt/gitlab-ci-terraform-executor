##############################################################################
## AWS VM IMPORT REQUIREMENTS

# Create base policy for vmimport with S3 storage.
data "aws_iam_policy_document" "vmimport_s3_aoc" {
  statement {
    sid = "VMImportS3Policy"

    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::image-builder.service",
      "arn:aws:s3:::image-builder.service/*",
    ]
  }
}

# Create base policy for vmimport with EC2.
data "aws_iam_policy_document" "vmimport_ec2_aoc" {
  statement {
    sid = "VMImportEC2Policy"

    actions = [
      "ec2:CopySnapshot",
      "ec2:Describe*",
      "ec2:ModifySnapshotAttribute",
      "ec2:DeleteTags",
      "ec2:CreateTags",
      "ec2:RegisterImage",
      "ec2:ImportSnapshot",
      "ec2:ModifyImageAttribute"
    ]

    resources = ["*"]
  }
}

# Load the vmimport S3/EC2 policies
resource "aws_iam_policy" "vmimport_s3_aoc" {
  name   = "vmimport_s3_aoc_${local.workspace_name}"
  policy = data.aws_iam_policy_document.vmimport_s3_aoc.json
}
resource "aws_iam_policy" "vmimport_ec2_aoc" {
  name   = "vmimport_ec2_aoc_${local.workspace_name}"
  policy = data.aws_iam_policy_document.vmimport_ec2_aoc.json
}

# Create the vmimport role.
resource "aws_iam_role" "vmimport_aoc" {
  name = "vmimport_aoc_${local.workspace_name}"

  # vmimport_trust.json is defined in workers-iam.tf
  assume_role_policy = data.aws_iam_policy_document.vmimport_trust.json

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder vmimport role for aoc - ${local.workspace_name}" },
  )
}

# Attach base vmimport policy to role.
resource "aws_iam_role_policy_attachment" "vmimport_s3_aoc" {
  role       = aws_iam_role.vmimport_aoc.name
  policy_arn = aws_iam_policy.vmimport_s3.arn
}
resource "aws_iam_role_policy_attachment" "vmimport_ec2_aoc" {
  role       = aws_iam_role.vmimport_aoc.name
  policy_arn = aws_iam_policy.vmimport_ec2.arn
}

##############################################################################
## SPOT FLEET
# Set up a role policy for spot fleets.
# The spot fleet aws_iam_policy_documents are defined in workers-iam.tf
resource "aws_iam_policy" "spotfleet_iam_spot_policy_aoc" {
  name   = "spotfleet_iam_spot_policy_aoc_${local.workspace_name}"
  policy = data.aws_iam_policy_document.spotfleet_iam_spot_policy.json
}

# Create the spot fleet role.
resource "aws_iam_role" "spot_fleet_tagging_role_aoc" {
  assume_role_policy = data.aws_iam_policy_document.spotfleet_iam_role_policy.json
  name               = "imagebuilder_spot_fleet_role_aoc_${local.workspace_name}"
}

# Attach the tagging policy to the spot fleet.role
resource "aws_iam_role_policy_attachment" "spotfleet_iam_role_policy_aoc" {
  role       = aws_iam_role.spot_fleet_tagging_role_aoc.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}
resource "aws_iam_role_policy_attachment" "spotfleet_iam_spot_policy_aoc" {
  role       = aws_iam_role.spot_fleet_tagging_role_aoc.name
  policy_arn = aws_iam_policy.spotfleet_iam_spot_policy_aoc.arn
}

##############################################################################
## S3
# Create S3 bucket for workers to upload images.
resource "aws_s3_bucket" "imagebuilder_s3_aoc" {
  bucket = "image-builder.service.${local.workspace_name}"
  acl    = "private"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder S3 AOC bucket - ${local.workspace_name}" },
  )
}

# Generate policy to allow workers to upload images to S3.
data "aws_iam_policy_document" "imagebuilder_s3_aoc" {
  statement {
    sid = "1"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]

    resources = [
      aws_s3_bucket.imagebuilder_s3_aoc.arn,
      "${aws_s3_bucket.imagebuilder_s3_aoc.arn}/*"
    ]
  }
}

# Create policy based on s3 upload policy document.
resource "aws_iam_policy" "imagebuilder_workers_aoc_s3" {
  name   = "imagebuilder_workers_aoc_s3_${local.workspace_name}"
  policy = data.aws_iam_policy_document.imagebuilder_s3_aoc.json
}

# Create the IAM user.
resource "aws_iam_user" "imagebuilder_worker_aoc" {
  name = "imagebuilder_worker_aoc_${local.workspace_name}"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder AOC Worker - ${local.workspace_name}" },
  )
}

# Attach policies.
resource "aws_iam_user_policy_attachment" "imagebuilder_s3_aoc" {
  user       = aws_iam_user.imagebuilder_worker_aoc.name
  policy_arn = aws_iam_policy.imagebuilder_workers_aoc_s3.arn
}
resource "aws_iam_user_policy_attachment" "imagebuilder_vmimport_aoc" {
  user       = aws_iam_user.imagebuilder_worker_aoc.name
  policy_arn = aws_iam_policy.vmimport_ec2.arn
}
