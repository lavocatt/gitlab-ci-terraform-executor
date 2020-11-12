# IAM configurations that must be applied by a human outside of GitHub or
# CodeBuild automation.
variable "imagebuilder_tags" {
  type = map
  default = {
    Name : "Image Builder Terraform State Storage"
    ServiceOwner : "Image Builder"
    AppCode : "IMGB-001"
  }
}

# Create the github_actions user.
resource "aws_iam_user" "github_actions_readonly" {
  name = "github_actions"
  tags = var.imagebuilder_tags
}

# Create IAM policies from our policy documents.
resource "aws_iam_policy" "terraform_read_state" {
  name   = "terraform_read_state"
  policy = data.aws_iam_policy_document.terraform_read_state.json
}
resource "aws_iam_policy" "terraform_locks" {
  name   = "terraform_locks"
  policy = data.aws_iam_policy_document.terraform_locks.json
}


# Attach the IAM policies to our github_actions user.
resource "aws_iam_user_policy_attachment" "viewonly" {
  user       = aws_iam_user.github_actions_readonly.name
  policy_arn = data.aws_iam_policy.viewonly.arn
}
resource "aws_iam_user_policy_attachment" "read_only_iam" {
  user       = aws_iam_user.github_actions_readonly.name
  policy_arn = data.aws_iam_policy.read_only_iam.arn
}
resource "aws_iam_user_policy_attachment" "read_only_codebuild" {
  user       = aws_iam_user.github_actions_readonly.name
  policy_arn = data.aws_iam_policy.read_only_codebuild.arn
}
resource "aws_iam_user_policy_attachment" "terraform_read_state" {
  user       = aws_iam_user.github_actions_readonly.name
  policy_arn = aws_iam_policy.terraform_read_state.arn
}
resource "aws_iam_user_policy_attachment" "terraform_locks" {
  user       = aws_iam_user.github_actions_readonly.name
  policy_arn = aws_iam_policy.terraform_locks.arn
}
