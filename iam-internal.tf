# Create a policy that lets EC2 assume the role.
data "aws_iam_policy_document" "internal_infrastructure_ec2_principal" {
  statement {
    sid = "AllowEC2AssumeRole"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Create roles for the internal composer and workers to use.
resource "aws_iam_role" "internal_worker" {
  name = "internal_worker_${local.workspace_name}"

  assume_role_policy = data.aws_iam_policy_document.internal_infrastructure_ec2_principal.json

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder internal worker role - ${local.workspace_name}" },
  )
}

resource "aws_iam_role" "internal_composer" {
  name = "internal_composer_${local.workspace_name}"

  assume_role_policy = data.aws_iam_policy_document.internal_infrastructure_ec2_principal.json

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder internal composer role - ${local.workspace_name}" },
  )
}

# Link instance profiles to the roles.
resource "aws_iam_instance_profile" "internal_worker" {
  name = "internal_worker_${local.workspace_name}"
  role = aws_iam_role.internal_worker.name
}

resource "aws_iam_instance_profile" "internal_composer" {
  name = "internal_composer_${local.workspace_name}"
  role = aws_iam_role.internal_composer.name
}

# Create policies that allows for reading secrets.
data "aws_iam_policy_document" "internal_worker_read_keys" {
  statement {
    sid = "WorkerReadSecrets"

    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      data.aws_secretsmanager_secret.internal_worker_keys.arn
    ]
  }
}

data "aws_iam_policy_document" "internal_composer_read_keys" {
  statement {
    sid = "ComposerReadSecrets"

    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      data.aws_secretsmanager_secret.internal_composer_keys.arn
    ]
  }
}

# Load the internal secrets policies.
resource "aws_iam_policy" "internal_worker_read_keys" {
  name   = "internal_worker_read_keys_${local.workspace_name}"
  policy = data.aws_iam_policy_document.internal_worker_read_keys.json
}

resource "aws_iam_policy" "internal_composer_read_keys" {
  name   = "internal_composer_read_keys_${local.workspace_name}"
  policy = data.aws_iam_policy_document.internal_composer_read_keys.json
}

# Attach the internal secrets policies to the internal worker and composer roles.
resource "aws_iam_role_policy_attachment" "internal_worker_read_keys" {
  role       = aws_iam_role.internal_worker.name
  policy_arn = aws_iam_policy.internal_worker_read_keys.arn
}

resource "aws_iam_role_policy_attachment" "internal_composer_read_keys" {
  role       = aws_iam_role.internal_composer.name
  policy_arn = aws_iam_policy.internal_composer_read_keys.arn
}

# Create a policy that allows internal composer/workers to send log data to
# cloudwatch.
data "aws_iam_policy_document" "internal_cloudwatch_logging" {
  statement {
    sid = "BasicCloudWatchUsage"

    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeVolumes",
      "ec2:DescribeTags",
    ]

    resources = ["*"]
  }

  statement {
    sid = "CloudWatchPutLogEvents"

    actions = [
      "logs:PutLogEvents"
    ]

    resources = [
      aws_cloudwatch_log_stream.internal_composer_syslog.arn
    ]
  }

  statement {
    sid = "CloudWatchDescribeLogStreams"

    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup"
    ]

    resources = [
      "${aws_cloudwatch_log_group.internal_composer.arn}:log-stream:"
    ]
  }
}

# Load the CloudWatch policy.
resource "aws_iam_policy" "internal_cloudwatch_logging" {
  name   = "internal_cloudwatch_logging_${local.workspace_name}"
  policy = data.aws_iam_policy_document.internal_cloudwatch_logging.json
}

# Attach the CloudWatch policy to both roles.
resource "aws_iam_role_policy_attachment" "internal_cloudwatch_composer" {
  role       = aws_iam_role.internal_worker.name
  policy_arn = aws_iam_policy.internal_cloudwatch_logging.arn
}

resource "aws_iam_role_policy_attachment" "internal_cloudwatch_worker" {
  role       = aws_iam_role.internal_composer.name
  policy_arn = aws_iam_policy.internal_cloudwatch_logging.arn
}
