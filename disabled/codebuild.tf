# Resources for CodeBuild at AWS that deploys our infrastructure.

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
  service_role  = aws_iam_role.codebuild_imagebuilder.arn

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
