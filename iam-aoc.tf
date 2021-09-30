# Create a policy that lets EC2 assume the role.
data "aws_iam_policy_document" "infrastructure_ec2_principal_aoc" {
  statement {
    sid = "AllowEC2AssumeRole"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Create role for the aoc workers to use
resource "aws_iam_role" "worker_aoc" {
  name = "workers_aoc"

  assume_role_policy = data.aws_iam_policy_document.infrastructure_ec2_principal_aoc.json

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder aoc worker role" },
  )
}

# Link instance profiles to the roles.
resource "aws_iam_instance_profile" "worker_aoc" {
  name = "worker_aoc"
  role = aws_iam_role.worker_aoc.name
}

# Create policies that allows for reading secrets.
data "aws_iam_policy_document" "worker_aoc_read_keys" {
  statement {
    sid = "WorkerReadSecrets"

    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      data.aws_secretsmanager_secret.offline_token.arn,
      data.aws_secretsmanager_secret.subscription_manager_command.arn,
      data.aws_secretsmanager_secret.gcp_service_account_image_builder.arn,
      data.aws_secretsmanager_secret.azure_account_image_builder.arn
    ]
  }
}

# Load the external secrets policies.
resource "aws_iam_policy" "worker_aoc_read_keys" {
  name   = "worker_aoc_read_keys"
  policy = data.aws_iam_policy_document.worker_aoc_read_keys.json
}

# Attach the external secrets policies to the external worker and composer roles.
resource "aws_iam_role_policy_attachment" "worker_aoc_read_keys" {
  role       = aws_iam_role.worker_aoc.name
  policy_arn = aws_iam_policy.worker_aoc_read_keys.arn
}

# Create a policy that allows external composer/workers to send log data to
# cloudwatch.
data "aws_iam_policy_document" "cloudwatch_logging_aoc" {
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
      aws_cloudwatch_log_stream.worker_aoc_syslog.arn
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
      "${aws_cloudwatch_log_group.workers_aoc.arn}:log-stream:"
    ]
  }
}

# Load the CloudWatch policy.
resource "aws_iam_policy" "cloudwatch_logging_aoc" {
  name   = "cloudwatch_logging_aoc"
  policy = data.aws_iam_policy_document.cloudwatch_logging_aoc.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_worker_aoc" {
  role       = aws_iam_role.worker_aoc.name
  policy_arn = aws_iam_policy.cloudwatch_logging_aoc.arn
}

# Attach the monitoring client policy.
resource "aws_iam_role_policy_attachment" "pozorbot_worker_aoc" {
  role       = aws_iam_role.worker_aoc.name
  policy_arn = aws_iam_policy.pozorbot_client_sqs.arn
}
