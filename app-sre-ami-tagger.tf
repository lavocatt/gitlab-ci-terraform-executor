data "aws_iam_policy_document" "app_interface_ami_tagger" {
  statement {
    actions = [
      "ec2:DescribeImages",
      "ec2:CreateTags"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "app_interface_ami_tagger" {
  name   = local.workspace_name == "staging" ? "app-interface-ami-tagger" : "app-interface-ami-tagger-unused"
  policy = data.aws_iam_policy_document.app_interface_ami_tagger.json
}

resource "aws_iam_user" "app_interface_ami_tagger" {
  name = local.workspace_name == "staging" ? "app-interface-ami-tagger" : "app-interface-ami-tagger-unused"

  tags = {
    vault-creds = "https://vault.devshift.net/ui/vault/secrets/image-builder-ci/show/packer/app-interface-ami-tagger",
    used-by     = "https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/aws/image-builder-ci/account.yml"
  }
}

resource "aws_iam_user_policy_attachment" "app_interface_ami_tagger" {
  user       = aws_iam_user.app_interface_ami_tagger.name
  policy_arn = aws_iam_policy.app_interface_ami_tagger.arn
}

resource "aws_iam_access_key" "app_interface_ami_tagger" {
  user = aws_iam_user.app_interface_ami_tagger.name
}
