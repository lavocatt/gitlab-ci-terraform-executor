terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

data "aws_iam_policy_document" "gitlab_ci_ec2_principal" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "gitlab_ci" {
  name = "gitlab_ci_${var.workspace_name}"

  assume_role_policy = data.aws_iam_policy_document.gitlab_ci_ec2_principal.json

  tags = merge(
  var.imagebuilder_tags, { Name = "Image Builder GitLab CI role" },
  )
}

resource "aws_iam_instance_profile" "gitlab_ci" {
  name = "gitlab_ci_${var.workspace_name}"
  role = aws_iam_role.gitlab_ci.name
}

data "aws_iam_policy_document" "gitlab_ci_manage_instances" {
  statement {
    actions = [
      "ec2:DescribeSpotInstanceRequests",
      "ec2:CancelSpotInstanceRequests",
      "ec2:GetConsoleOutput",
      "ec2:RequestSpotInstances",
      "ec2:RunInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeInstances",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeRegions",
      "ec2:DescribeImages",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcs",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "gitlab_ci_manage_instances" {
  name   = "gitlab_ci_manage_instances_${var.workspace_name}"
  policy = data.aws_iam_policy_document.gitlab_ci_manage_instances.json
}

resource "aws_iam_role_policy_attachment" "gitlab_ci_manage_instances" {
  role       = aws_iam_role.gitlab_ci.name
  policy_arn = aws_iam_policy.gitlab_ci_manage_instances.arn
}

resource "aws_security_group" "gitlab_ci_runner_internal" {
  name        = "gitlab_ci_runner_internal_${var.workspace_name}"
  description = "GitLab CI"
  vpc_id      = var.internal_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }


  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
  var.imagebuilder_tags, { Name = "gitlab_ci_runner_internal_${var.workspace_name}" },
  )
}

resource "aws_security_group" "gitlab_ci_runner_external" {
  name        = "gitlab_ci_runner_external_${var.workspace_name}"
  description = "GitLab CI"
  vpc_id      = var.external_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
  var.imagebuilder_tags, { Name = "gitlab_ci_runner_external_${var.workspace_name}" },
  )
}
