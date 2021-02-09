##############################################################################
## SCHUTZBOT WEBHOOK

# Queue to hold webhook data for the consumer.
resource "aws_sqs_queue" "schutzbot_webhook_sqs" {
  name = "schutzbot_webhook_sqs-${local.workspace_name}"

  # SQS has tight restrictions on tags.
  # Tag values may only contain unicode letters, digits, whitespace,
  # or one of these symbols: _ . : / = + - @
  tags = merge(
    var.imagebuilder_tags,
    { Name = "Schutzbot Webhook SQS - ${local.workspace_name}" }
  )
}

# IAM policy to allow sending, receiving, and deleting messages.
data "aws_iam_policy_document" "schutzbot_webhook_sqs" {
  statement {
    sid = "PozorbotSQS"

    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.schutzbot_webhook_sqs.arn
    ]
  }
}

# Load the SQS policy into IAM.
resource "aws_iam_policy" "schutzbot_webhook_sqs" {
  name   = "schutzbot_webhook_sqs_${local.workspace_name}"
  policy = data.aws_iam_policy_document.schutzbot_webhook_sqs.json
}

# Create the IAM user.
resource "aws_iam_user" "schutzbot_webhook_sqs" {
  name = "schutzbot_webhook_${local.workspace_name}"

  tags = merge(
    var.imagebuilder_tags, { Name = "Schutzbot Webhook - ${local.workspace_name}" },
  )
}

# Attach policies.
resource "aws_iam_user_policy_attachment" "schutzbot_webhook_sqs" {
  user       = aws_iam_user.schutzbot_webhook_sqs.name
  policy_arn = aws_iam_policy.schutzbot_webhook_sqs.arn
}
