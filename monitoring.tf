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
    { Name = "Pozorbot Message Queue - ${local.workspace_name}" }
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

  tags = merge(
    var.imagebuilder_tags,
    { Name = "Pozorbot lambda role - ${local.workspace_name}" }
  )
}

# Prepare Lambda package (https://github.com/hashicorp/terraform/issues/8344#issuecomment-345807204)
resource "null_resource" "pip" {
  triggers = {
    main         = base64sha256(file("lambda/pozorbot.py"))
    requirements = base64sha256(file("lambda/requirements.txt"))
  }

  provisioner "local-exec" {
    command = "/usr/bin/pip install -r ${path.root}/lambda/requirements.txt -t lambda/lib"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/lambda/"
  output_path = "${path.root}/pozorbot.zip"

  depends_on = [null_resource.pip]
}

# Pozorbot lambda function to send alerts to telegram.
resource "aws_lambda_function" "pozorbot_lambda" {
  filename         = "pozorbot.zip"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "pozorbot_${local.workspace_name}"
  role             = aws_iam_role.pozorbot_lambda_role.arn
  handler          = "pozorbot.lambda_handler"
  runtime          = "python3.6"

  environment {
    variables = {
      TOKEN   = "token_value",
      USER_ID = "user_id_value"
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
