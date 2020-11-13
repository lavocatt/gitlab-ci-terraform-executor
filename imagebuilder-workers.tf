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

resource "aws_iam_user" "imagebuilder_stage" {
  name = "imagebuilder-stage"
  path = "/workers/"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder Stage User" },
  )
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

resource "aws_iam_user" "imagebuilder_prod" {
  name = "imagebuilder-prod"
  path = "/workers/"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder Prod User" },
  )
}
