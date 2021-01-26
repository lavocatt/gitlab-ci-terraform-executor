##############################################################################
## MONITORING

# AWS SNS queue to hold messages sent by monitoring.
resource "aws_sqs_queue" "image_builder_pozorbot" {
  name                        = "image-builder-pozorbot-${local.workspace_name}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true

  # SQS has tight restrictions on tags.
  # Tag values may only contain unicode letters, digits, whitespace,
  # or one of these symbols: _ . : / = + - @
  tags = merge(
    var.imagebuilder_tags,
    { Name = "Pozorbot Message Queue (${local.workspace_name})" }
  )
}

# Policy for Pozorbot lambda role.
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
}

# Pozorbot lambda function to send alerts to telegram.
resource "aws_lambda_function" "pozorbot_lambda" {
  filename         = "pozorbot.zip"
  source_code_hash = filebase64sha256("pozorbot.zip")
  function_name    = "pozorbot_${local.workspace_name}"
  role             = aws_iam_role.pozorbot_lambda_role.arn
  handler          = "pozorbot.lambda_handler"
  runtime          = "python3.8"

  environment {
    variables = {
      foo = "bar"
    }
  }

  tags = merge(
    var.imagebuilder_tags,
    { Name = "🚨 Pozorbot lambda (${local.workspace_name})" }
  )
}

# Ensure new messages trigger the lambda function.
resource "aws_lambda_event_source_mapping" "pozorbot_sqs" {
  event_source_arn = aws_sqs_queue.image_builder_pozorbot.arn
  function_name    = aws_lambda_function.pozorbot_lambda.arn
}
