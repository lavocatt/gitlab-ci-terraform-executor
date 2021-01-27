# Create a policy that lets EC2 assume the role.
data "aws_iam_policy_document" "external_infrastructure_ec2_principal" {
  statement {
    sid = "AllowEC2AssumeRole"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Create roles for the external composer and workers to use.
resource "aws_iam_role" "external_worker" {
  name = "external_worker_${local.workspace_name}"

  assume_role_policy = data.aws_iam_policy_document.external_infrastructure_ec2_principal.json

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder external worker role - ${local.workspace_name}" },
  )
}

resource "aws_iam_role" "external_composer" {
  name = "external_composer_${local.workspace_name}"

  assume_role_policy = data.aws_iam_policy_document.external_infrastructure_ec2_principal.json

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder external composer role - ${local.workspace_name}" },
  )
}

# Link instance profiles to the roles.
resource "aws_iam_instance_profile" "external_worker" {
  name = "external_worker_${local.workspace_name}"
  role = aws_iam_role.external_worker.name
}

resource "aws_iam_instance_profile" "external_composer" {
  name = "external_composer_${local.workspace_name}"
  role = aws_iam_role.external_composer.name
}

# Create policies that allows for reading secrets.
data "aws_iam_policy_document" "external_worker_read_keys" {
  statement {
    sid = "WorkerReadSecrets"

    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      data.aws_secretsmanager_secret.external_worker_keys.arn,
      data.aws_secretsmanager_secret.subscription_manager_command.arn
    ]
  }
}

data "aws_iam_policy_document" "external_composer_read_keys" {
  statement {
    sid = "ComposerReadSecrets"

    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      data.aws_secretsmanager_secret.external_composer_keys.arn,
      data.aws_secretsmanager_secret.subscription_manager_command.arn
    ]
  }
}

# Load the external secrets policies.
resource "aws_iam_policy" "external_worker_read_keys" {
  name   = "external_worker_read_keys_${local.workspace_name}"
  policy = data.aws_iam_policy_document.external_worker_read_keys.json
}

resource "aws_iam_policy" "external_composer_read_keys" {
  name   = "external_composer_read_keys_${local.workspace_name}"
  policy = data.aws_iam_policy_document.external_composer_read_keys.json
}

# Attach the external secrets policies to the external worker and composer roles.
resource "aws_iam_role_policy_attachment" "external_worker_read_keys" {
  role       = aws_iam_role.external_worker.name
  policy_arn = aws_iam_policy.external_worker_read_keys.arn
}

resource "aws_iam_role_policy_attachment" "external_composer_read_keys" {
  role       = aws_iam_role.external_composer.name
  policy_arn = aws_iam_policy.external_composer_read_keys.arn
}

# Create a policy that allows external composer/workers to send log data to
# cloudwatch.
data "aws_iam_policy_document" "external_cloudwatch_logging" {
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
    sid = "CloudWatchSendLogs"

    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup"
    ]

    resources = [
      aws_cloudwatch_log_group.external_composer.arn,
      aws_cloudwatch_log_stream.external_composer_syslog.arn
    ]
  }
}

# Load the CloudWatch policy.
resource "aws_iam_policy" "external_cloudwatch_logging" {
  name   = "external_cloudwatch_logging_${local.workspace_name}"
  policy = data.aws_iam_policy_document.external_cloudwatch_logging.json
}

# Attach the CloudWatch policy to both roles.
resource "aws_iam_role_policy_attachment" "external_cloudwatch_composer" {
  role       = aws_iam_role.external_worker.name
  policy_arn = aws_iam_policy.external_cloudwatch_logging.arn
}

resource "aws_iam_role_policy_attachment" "external_cloudwatch_worker" {
  role       = aws_iam_role.external_composer.name
  policy_arn = aws_iam_policy.external_cloudwatch_logging.arn
}

# Attach the monitoring client policy.
resource "aws_iam_role_policy_attachment" "external_pozorbot_composer" {
  role       = aws_iam_role.external_worker.name
  policy_arn = aws_iam_policy.pozorbot_client_sqs.arn
}

resource "aws_iam_role_policy_attachment" "external_pozorbot_worker" {
  role       = aws_iam_role.external_composer.name
  policy_arn = aws_iam_policy.pozorbot_client_sqs.arn
}
