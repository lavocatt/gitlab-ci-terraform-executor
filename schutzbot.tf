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

# SQS policy that allows anonymous sending of messages.
data "aws_iam_policy_document" "schutzbot_webhook_sendmessage" {
  statement {
    sid = "SchutzbotSQSAnonymous"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["sqs:SendMessage"]

    resources = [
      aws_sqs_queue.schutzbot_webhook_sqs.arn
    ]
  }
}

# Attach the SQS policy to the queue.
resource "aws_sqs_queue_policy" "test" {
  queue_url = aws_sqs_queue.schutzbot_webhook_sqs.id
  policy    = data.aws_iam_policy_document.schutzbot_webhook_sendmessage.json
}

# IAM policy to allow sending, receiving, and deleting messages.
data "aws_iam_policy_document" "schutzbot_webhook_sqs" {
  statement {
    sid = "SchutzbotSQS"

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
