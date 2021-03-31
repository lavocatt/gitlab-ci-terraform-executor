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
  name = "gitlab_ci-${local.workspace_name}"

  assume_role_policy = data.aws_iam_policy_document.gitlab_ci_ec2_principal.json

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder GitLab CI role" },
  )
}

resource "aws_iam_instance_profile" "gitlab_ci" {
  name = "gitlab_ci-${local.workspace_name}"
  role = aws_iam_role.gitlab_ci.name
}

data "aws_iam_policy_document" "gitlab_ci_manage_instances" {
  statement {
    actions = [
      "ec2:DescribeSpotInstanceRequests",
      "ec2:CancelSpotInstanceRequests",
      "ec2:RequestSpotInstances",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:DescribeInstances",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "gitlab_ci_manage_instances" {
  name   = "gitlab_ci_manage_instances-${local.workspace_name}"
  policy = data.aws_iam_policy_document.gitlab_ci_manage_instances.json
}

resource "aws_iam_role_policy_attachment" "gitlab_ci_manage_instances" {
  role       = aws_iam_role.gitlab_ci.name
  policy_arn = aws_iam_policy.gitlab_ci_manage_instances.arn
}
