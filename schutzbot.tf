##############################################################################
## MONITORING

# AWS SQS queue to hold webhook messages until a consumer picks them up.
resource "aws_sqs_queue" "schutzbot_receiver_queue" {
  name = "schutzbot-receiver-queue-${local.workspace_name}"

  # SQS has tight restrictions on tags.
  # Tag values may only contain unicode letters, digits, whitespace,
  # or one of these symbols: _ . : / = + - @
  tags = merge(
    var.imagebuilder_tags,
    { Name = "Schutzbot Receiver Message Queue - ${local.workspace_name}" }
  )
}

# Create a cloudwatch log group to receive logs from the lambda function.
# NOTE(mhayden): AWS chooses the cloudwatch log group name automatically, so
# the path below **must be** /aws/lambda/{function_name}.
resource "aws_cloudwatch_log_group" "schutzbot_receiver_logs" {
  name = "/aws/lambda/schutzbot_receiver_${local.workspace_name}"

  tags = merge(
    var.imagebuilder_tags, { Name = "Schutzbot ${local.workspace_name}" },
  )
}

# Create policy to allow the lambda function to log to cloudwatch.
data "aws_iam_policy_document" "schutzbot_receiver_cloudwatch" {
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
      "${aws_cloudwatch_log_group.schutzbot_receiver_logs.arn}:*"
    ]
  }
}

# Load the lambda cloudwatch policy into IAM.
resource "aws_iam_policy" "schutzbot_receiver_cloudwatch" {
  name   = "schutzbot_receiver_cloudwatch_${local.workspace_name}"
  policy = data.aws_iam_policy_document.schutzbot_receiver_cloudwatch.json
}

# Create policy to allow the lambda function publish SQS messages.
data "aws_iam_policy_document" "schutzbot_receiver_sqs" {
  statement {
    sid = "PozorbotSQS"

    actions = [
      "sqs:GetQueueAttributes",
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.schutzbot_receiver_queue.arn
    ]
  }
}

# Load the lambda SQS policy into IAM.
resource "aws_iam_policy" "schutzbot_receiver_sqs" {
  name   = "schutzbot_receiver_sqs_${local.workspace_name}"
  policy = data.aws_iam_policy_document.schutzbot_receiver_sqs.json
}

# Create policy to allow the lambda to read secrets from secrets manager.
data "aws_iam_policy_document" "schutzbot_receiver_read_secrets" {
  statement {
    sid = "SchutzbotReceiverReadSecrets"

    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      data.aws_secretsmanager_secret.schutzbot_receiver.arn
    ]
  }
}

# Load the lambda secrets policy into IAM.
resource "aws_iam_policy" "schutzbot_receiver_read_secrets" {
  name   = "schutzbot_receiver_read_secrets_${local.workspace_name}"
  policy = data.aws_iam_policy_document.schutzbot_receiver_read_secrets.json
}

# Role policy for the lambda function.
data "aws_iam_policy_document" "schutzbot_receiver_lambda_policy" {
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
resource "aws_iam_role" "schutzbot_receiver_lambda_role" {
  name = "schutzbot_receiver_lambda_role_${local.workspace_name}"

  assume_role_policy = data.aws_iam_policy_document.schutzbot_receiver_lambda_policy.json

  tags = merge(
    var.imagebuilder_tags,
    { Name = "Schutzbot receiver lambda role - ${local.workspace_name}" }
  )
}

# Attach the lambda cloudwatch policy to the schutzbot_receiver lambda role.
resource "aws_iam_role_policy_attachment" "schutzbot_receiver_cloudwatch" {
  role       = aws_iam_role.schutzbot_receiver_lambda_role.name
  policy_arn = aws_iam_policy.schutzbot_receiver_cloudwatch.arn
}

# Attach the lambda SQS policy to the schutzbot_receiver lambda role.
resource "aws_iam_role_policy_attachment" "schutzbot_receiver_sqs" {
  role       = aws_iam_role.schutzbot_receiver_lambda_role.name
  policy_arn = aws_iam_policy.schutzbot_receiver_sqs.arn
}

# Attach the lambda secrets policy to the schutzbot_receiver lambda role.
resource "aws_iam_role_policy_attachment" "schutzbot_receiver_lambda_secrets" {
  role       = aws_iam_role.schutzbot_receiver_lambda_role.name
  policy_arn = aws_iam_policy.schutzbot_receiver_read_secrets.arn
}

# Package the python script into a zip file.
data "archive_file" "schutzbot_receiver_lambda_zip" {
  type        = "zip"
  source_file = "${path.root}/lambda/schutzbot_receiver.py"
  output_path = "${path.root}/schutzbot_receiver.zip"
}

# Schutzbot receiver lambda function.
resource "aws_lambda_function" "schutzbot_receiver_lambda" {
  filename         = "schutzbot_receiver.zip"
  source_code_hash = data.archive_file.schutzbot_receiver_lambda_zip.output_base64sha256
  function_name    = "schutzbot_receiver_${local.workspace_name}"
  role             = aws_iam_role.schutzbot_receiver_lambda_role.arn
  handler          = "schutzbot_receiver.github_webhook_endpoint"
  runtime          = "python3.8"

  layers = [data.aws_lambda_layer_version.schutzbot_receiver.arn]

  environment {
    variables = {
      SECRET_REGION = data.aws_region.current.name,
      SECRET_NAME   = "schutzbot_receiver",
      SQS_REGION    = data.aws_region.current.name,
      SQS_QUEUE     = "schutzbot-receiver-queue-${local.workspace_name}"
    }
  }

  tags = merge(
    var.imagebuilder_tags,
    { Name = "Schutzbot receiver lambda ${local.workspace_name}" }
  )
}

##############################################################################
## LAMBDA GATEWAY
resource "aws_api_gateway_rest_api" "schutzbot_receiver_api" {
  name = "schutzbot-receiver-api-${local.workspace_name}"
}

resource "aws_api_gateway_resource" "schutzbot_receiver_resource" {
  path_part   = "{proxy+}"
  parent_id   = aws_api_gateway_rest_api.schutzbot_receiver_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.schutzbot_receiver_api.id
}

resource "aws_api_gateway_method" "schutzbot_receiver_method" {
  rest_api_id   = aws_api_gateway_rest_api.schutzbot_receiver_api.id
  resource_id   = aws_api_gateway_resource.schutzbot_receiver_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "schutzbot_receiver_integration" {
  rest_api_id = aws_api_gateway_rest_api.schutzbot_receiver_api.id
  resource_id = aws_api_gateway_resource.schutzbot_receiver_resource.id
  http_method = aws_api_gateway_method.schutzbot_receiver_method.http_method
  uri         = aws_lambda_function.schutzbot_receiver_lambda.invoke_arn

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
}

resource "aws_api_gateway_deployment" "schutzbot_receiver_deployment" {
  depends_on = [
    aws_api_gateway_integration.schutzbot_receiver_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.schutzbot_receiver_api.id
}

resource "aws_lambda_permission" "schutzbot_receiver_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.schutzbot_receiver_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.schutzbot_receiver_api.id}/*/${aws_api_gateway_method.schutzbot_receiver_method.http_method}${aws_api_gateway_resource.schutzbot_receiver_resource.path}"
}

##############################################################################
## MONITORING CLIENTS

# Create policy to allow clients to send monitoring messages into SQS
data "aws_iam_policy_document" "schutzbot_receiver_consumer_sqs" {
  statement {
    sid = "SchutzbotReceiverConsumerSQS"

    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage"
    ]

    resources = [
      aws_sqs_queue.schutzbot_receiver_queue.arn
    ]
  }
}

# Load the lambda secrets policy into IAM.
resource "aws_iam_policy" "schutzbot_receiver_consumer_sqs" {
  name   = "schutzbot_receiver_consumer_sqs_${local.workspace_name}"
  policy = data.aws_iam_policy_document.schutzbot_receiver_consumer_sqs.json
}

# Create the IAM user.
resource "aws_iam_user" "schutzbot_receiver_consumer" {
  name = "schutzbot_receiver_consumer_${local.workspace_name}"

  tags = merge(
    var.imagebuilder_tags, { Name = "Schutzbot Receiver Consumer - ${local.workspace_name}" },
  )
}

# Attach policies.
resource "aws_iam_user_policy_attachment" "schutzbot_receiver_consumer" {
  user       = aws_iam_user.schutzbot_receiver_consumer.name
  policy_arn = aws_iam_policy.schutzbot_receiver_consumer_sqs.arn
}
