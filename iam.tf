##############################################################################
## POLICY LOOKUPS
# Get the policy from IAM that allows reading everything.
data "aws_iam_policy" "readonly" {
  arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Get the IAMFullAccess policy.
data "aws_iam_policy" "iam_full_access" {
  arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

##############################################################################
## CUSTOM POLICIES
# Allow Terraform to read state from S3.
data "aws_iam_policy_document" "terraform_read_state" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${var.state_bucket}",
      "arn:aws:s3:::${var.state_bucket}/*"
    ]
  }
}
resource "aws_iam_policy" "terraform_read_state" {
  name   = "terraform_read_state"
  policy = data.aws_iam_policy_document.terraform_read_state.json
}

# Allow Terraform to write state to S3.
data "aws_iam_policy_document" "terraform_write_state" {
  statement {
    actions = ["s3:PutObject"]

    resources = [
      "arn:aws:s3:::${var.state_bucket}",
      "arn:aws:s3:::${var.state_bucket}/*"
    ]
  }
}
resource "aws_iam_policy" "terraform_write_state" {
  name   = "terraform_write_state"
  policy = data.aws_iam_policy_document.terraform_write_state.json
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
resource "aws_iam_policy" "terraform_locks" {
  name   = "terraform_locks"
  policy = data.aws_iam_policy_document.terraform_locks.json
}

# Allow CodeBuild to send logs to CloudWatch.
data "aws_iam_policy_document" "codebuild_log_to_cloudwatch" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]

    resources = [
      "${aws_cloudwatch_log_group.codebuild_to_cloudwatch.arn}:*"
    ]
  }
}
resource "aws_iam_policy" "codebuild_log_to_cloudwatch" {
  name   = "codebuild_log_to_cloudwatch"
  policy = data.aws_iam_policy_document.codebuild_log_to_cloudwatch.json
}


# Base policy for CodeBuild to assume other roles.
data "aws_iam_policy_document" "codebuild_principal" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

##############################################################################
## USERS
# Create the github_actions user.
resource "aws_iam_user" "github_actions_readonly" {
  name = "github_actions"
  tags = var.imagebuilder_tags
}

##############################################################################
## USER/POLICY ATTACHMENT
# Attach the IAM policies to our github_actions user.
resource "aws_iam_user_policy_attachment" "readonly" {
  user       = aws_iam_user.github_actions_readonly.name
  policy_arn = data.aws_iam_policy.readonly.arn
}
resource "aws_iam_user_policy_attachment" "terraform_read_state" {
  user       = aws_iam_user.github_actions_readonly.name
  policy_arn = aws_iam_policy.terraform_read_state.arn
}
resource "aws_iam_user_policy_attachment" "terraform_locks" {
  user       = aws_iam_user.github_actions_readonly.name
  policy_arn = aws_iam_policy.terraform_locks.arn
}

##############################################################################
## ROLES
# Create the IAM role for CodeBuild.
resource "aws_iam_role" "codebuild_imagebuilder_deploy" {
  name               = "codebuild_imagebuilder_deploy"
  assume_role_policy = data.aws_iam_policy_document.codebuild_principal.json
}

##############################################################################
## ROLE/POLICY ATTACHMENT
# Attach all of the policies for CodeBuild.
resource "aws_iam_role_policy_attachment" "codebuild_cloudwatch" {
  role       = aws_iam_role.codebuild_imagebuilder_deploy.name
  policy_arn = aws_iam_policy.codebuild_log_to_cloudwatch.arn
}
resource "aws_iam_role_policy_attachment" "codebuild_read_state" {
  role       = aws_iam_role.codebuild_imagebuilder_deploy.name
  policy_arn = aws_iam_policy.terraform_read_state.arn
}
resource "aws_iam_role_policy_attachment" "codebuild_write_state" {
  role       = aws_iam_role.codebuild_imagebuilder_deploy.name
  policy_arn = aws_iam_policy.terraform_write_state.arn
}
resource "aws_iam_role_policy_attachment" "codebuild_terraform_locks" {
  role       = aws_iam_role.codebuild_imagebuilder_deploy.name
  policy_arn = aws_iam_policy.terraform_locks.arn
}
resource "aws_iam_role_policy_attachment" "codebuild_iam_full_access" {
  role       = aws_iam_role.codebuild_imagebuilder_deploy.name
  policy_arn = data.aws_iam_policy.iam_full_access.arn
}
resource "aws_iam_role_policy_attachment" "codebuild_readonly" {
  role       = aws_iam_role.codebuild_imagebuilder_deploy.name
  policy_arn = data.aws_iam_policy.readonly.arn
}
