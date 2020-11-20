# Create a policy that allows for reading Brew secrets.
data "aws_iam_policy_document" "brew_read_secrets" {
  statement {
    sid = "1"

    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:brew_secrets"
    ]
  }
}

# Load the Brew secrets policy.
resource "aws_iam_policy" "brew_read_secrets" {
  name   = "brew_read_secrets"
  policy = data.aws_iam_policy_document.brew_read_secrets.json
}

# Create a policy that lets EC2 assume the role.
data "aws_iam_policy_document" "brew_infrastructure_ec2_principal" {
  statement {
    sid = "1"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Create a role for Brew composer and workers to use.
resource "aws_iam_role" "brew_infrastructure" {
  name = "brew_infrastructure"

  assume_role_policy = data.aws_iam_policy_document.brew_infrastructure_ec2_principal.json

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder brew_infrastructure role" },
  )
}

# Attach the Brew secrets policy to the Brew role.
resource "aws_iam_role_policy_attachment" "brew_read_secrets" {
  role       = aws_iam_role.brew_infrastructure.name
  policy_arn = aws_iam_policy.brew_read_secrets.arn
}
