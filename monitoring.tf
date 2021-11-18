##############################################################################
## MONITORING

# AWS SNS queue to hold messages sent by monitoring.
resource "aws_sqs_queue" "image_builder_pozorbot" {
  name = "image-builder-pozorbot-${local.workspace_name}"

  # SQS has tight restrictions on tags.
  # Tag values may only contain unicode letters, digits, whitespace,
  # or one of these symbols: _ . : / = + - @
  tags = merge(
    var.imagebuilder_tags,
    { Name = "Pozorbot Message Queue - ${local.workspace_name}" }
  )
}

# Create a cloudwatch log group to receive logs from the lambda function.
# NOTE(mhayden): AWS chooses the cloudwatch log group name automatically, so
# the path below **must be** /aws/lambda/{function_name}.
resource "aws_cloudwatch_log_group" "pozorbot_cloudwatch_logs" {
  name = "/aws/lambda/pozorbot_${local.workspace_name}"

  tags = merge(
    var.imagebuilder_tags, { Name = "Pozorbot ${local.workspace_name}" },
  )
}

# Create policy to allow the lambda function to log to cloudwatch.
data "aws_iam_policy_document" "pozorbot_lambda_cloudwatch" {
  statement {
    sid = "PozorbotCloudwatch"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    # Asterisk on the end allows the lambda to write to various log streams
    # inside this log group.
    resources = [
      "${aws_cloudwatch_log_group.pozorbot_cloudwatch_logs.arn}:*"
    ]
  }
}

# Load the lambda cloudwatch policy into IAM.
resource "aws_iam_policy" "pozorbot_lambda_cloudwatch" {
  name   = "pozorbot_lambda_cloudwatch_${local.workspace_name}"
  policy = data.aws_iam_policy_document.pozorbot_lambda_cloudwatch.json
}

# Create policy to allow the lambda function to watch SQS.
data "aws_iam_policy_document" "pozorbot_lambda_sqs" {
  statement {
    sid = "PozorbotSQS"

    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage"
    ]

    resources = [
      aws_sqs_queue.image_builder_pozorbot.arn
    ]
  }
}

# Load the lambda SQS policy into IAM.
resource "aws_iam_policy" "pozorbot_lambda_sqs" {
  name   = "pozorbot_lambda_sqs_${local.workspace_name}"
  policy = data.aws_iam_policy_document.pozorbot_lambda_sqs.json
}

# Create policy to allow the lambda to read secrets from secrets manager.
data "aws_iam_policy_document" "pozorbot_read_secrets" {
  statement {
    sid = "WorkerReadSecrets"

    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      data.aws_secretsmanager_secret.pozorbot.arn
    ]
  }
}

# Load the lambda secrets policy into IAM.
resource "aws_iam_policy" "pozorbot_read_secrets" {
  name   = "pozorbot_read_secrets_${local.workspace_name}"
  policy = data.aws_iam_policy_document.pozorbot_read_secrets.json
}

# Role policy for the lambda function.
data "aws_iam_policy_document" "pozorbot_lambda_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    effect = "Allow"
  }
}

# Role with policy for lambda function.
resource "aws_iam_role" "pozorbot_lambda_role" {
  name = "pozorbot_lambda_role_${local.workspace_name}"

  assume_role_policy = data.aws_iam_policy_document.pozorbot_lambda_policy.json

  tags = merge(
    var.imagebuilder_tags,
    { Name = "Pozorbot lambda role - ${local.workspace_name}" }
  )
}

# Attach the lambda cloudwatch policy to the pozorbot lambda role.
resource "aws_iam_role_policy_attachment" "pozorbot_lambda_cloudwatch" {
  role       = aws_iam_role.pozorbot_lambda_role.name
  policy_arn = aws_iam_policy.pozorbot_lambda_cloudwatch.arn
}

# Attach the lambda SQS policy to the pozorbot lambda role.
resource "aws_iam_role_policy_attachment" "pozorbot_lambda_sqs" {
  role       = aws_iam_role.pozorbot_lambda_role.name
  policy_arn = aws_iam_policy.pozorbot_lambda_sqs.arn
}

# Attach the lambda secrets policy to the pozorbot lambda role.
resource "aws_iam_role_policy_attachment" "pozorbot_lambda_secrets" {
  role       = aws_iam_role.pozorbot_lambda_role.name
  policy_arn = aws_iam_policy.pozorbot_read_secrets.arn
}

# Package the python script into a zip file.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/lambda/"
  output_path = "${path.root}/pozorbot.zip"
}

# Pozorbot lambda function to send alerts to telegram.
resource "aws_lambda_function" "pozorbot_lambda" {
  filename         = "pozorbot.zip"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "pozorbot_${local.workspace_name}"
  role             = aws_iam_role.pozorbot_lambda_role.arn
  handler          = "pozorbot.lambda_handler"
  runtime          = "python3.8"

  environment {
    variables = {
      SECRET_REGION = data.aws_region.current.name,
      SECRET_NAME   = "pozorbot"
    }
  }

  tags = merge(
    var.imagebuilder_tags,
    { Name = "Pozorbot lambda ${local.workspace_name}" }
  )
}

# Ensure new messages trigger the lambda function.
resource "aws_lambda_event_source_mapping" "pozorbot_sqs" {
  event_source_arn = aws_sqs_queue.image_builder_pozorbot.arn
  function_name    = aws_lambda_function.pozorbot_lambda.arn
}

##############################################################################
## MONITORING CLIENTS

# Create policy to allow clients to send monitoring messages into SQS
data "aws_iam_policy_document" "pozorbot_client_sqs" {
  statement {
    sid = "PozorbotClientSQS"

    actions = [
      "sqs:GetQueueAttributes",
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.image_builder_pozorbot.arn
    ]
  }
}

# Load the lambda secrets policy into IAM.
resource "aws_iam_policy" "pozorbot_client_sqs" {
  name   = "pozorbot_client_sqs_${local.workspace_name}"
  policy = data.aws_iam_policy_document.pozorbot_client_sqs.json
}
