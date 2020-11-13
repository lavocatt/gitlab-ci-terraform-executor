# Resources for CodeBuild at AWS that deploys our infrastructure.

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

# Create the IAM role for CodeBuild.
resource "aws_iam_role" "codebuild_imagebuilder_deploy" {
  name               = "codebuild_imagebuilder_deploy"
  assume_role_policy = data.aws_iam_policy_document.codebuild_principal.json
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

# Create the CloudWatch policy.
resource "aws_iam_policy" "codebuild_log_to_cloudwatch" {
  name   = "codebuild_log_to_cloudwatch"
  policy = data.aws_iam_policy_document.codebuild_log_to_cloudwatch.json
}


# Attach the CloudWatch policy to the CodeBuild role.
resource "aws_iam_role_policy_attachment" "codebuild_log_to_cloudwatch" {
  role       = aws_iam_role.codebuild_imagebuilder_deploy.name
  policy_arn = aws_iam_policy.codebuild_log_to_cloudwatch.arn
}

# Allow CodeBuild to retrieve state and set up locking.
resource "aws_iam_role_policy_attachment" "terraform_read_state_codebuild" {
  role       = aws_iam_role.codebuild_imagebuilder_deploy.name
  policy_arn = aws_iam_policy.terraform_read_state.arn
}
resource "aws_iam_role_policy_attachment" "terraform_locks_codebuild" {
  role       = aws_iam_role.codebuild_imagebuilder_deploy.name
  policy_arn = aws_iam_policy.terraform_locks.arn
}

# Set up a CloudWatch log group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild_to_cloudwatch" {
  name              = "imagebuilder_codebuild"
  retention_in_days = 30

  tags = var.imagebuilder_tags
}

# Set up the CodeBuild project.
resource "aws_codebuild_project" "imagebuilder_terraform" {
  name          = "imagebuilder-terraform"
  description   = "imagebuilder-terraform deployment"
  badge_enabled = true
  service_role  = aws_iam_role.codebuild_imagebuilder_deploy.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  # These environment variables are passed to the container in CodeBuild.
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "docker.io/hashicorp/terraform:0.13.5"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "FOO"
      value = "BAR"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild_to_cloudwatch.name
      stream_name = "imagebuilder-terraform"
    }
  }

  source {
    type                = "GITHUB"
    location            = "https://github.com/osbuild/imagebuilder-terraform.git"
    git_clone_depth     = 1
    report_build_status = true
  }

  source_version = "main"
  tags           = var.imagebuilder_tags
}

resource "aws_codebuild_webhook" "imagebuilder_terraform" {
  project_name = aws_codebuild_project.imagebuilder_terraform.name

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "main"
    }
  }
}
