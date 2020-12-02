##############################################################################
## PACKER (temporary solution to chicken-and-egg problem)
# Set up a policy to allow Packer to do the things it needs to do with AWS.
data "aws_iam_policy_document" "packer" {
  statement {
    sid = "1"

    actions = [
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CopyImage",
      "ec2:CreateImage",
      "ec2:CreateKeypair",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteKeyPair",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSnapshot",
      "ec2:DeleteVolume",
      "ec2:DeregisterImage",
      "ec2:DescribeImageAttribute",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeRegions",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSnapshots",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DetachVolume",
      "ec2:GetPasswordData",
      "ec2:ModifyImageAttribute",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifySnapshotAttribute",
      "ec2:RegisterImage",
      "ec2:RunInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
      "ec2:CreateLaunchTemplate",
      "ec2:DeleteLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeVpcs"
    ]

    resources = ["*"]
  }
}

# Load the packer policy into IAM.
resource "aws_iam_policy" "packer" {
  name   = "packer"
  policy = data.aws_iam_policy_document.packer.json
}

# Create the Packer user.
resource "aws_iam_user" "packer" {
  name = "packer"
  path = "/packer/"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder Packer User" },
  )
}

# Attach the policy to the user.
resource "aws_iam_user_policy_attachment" "packer" {
  user       = aws_iam_user.packer.name
  policy_arn = aws_iam_policy.packer.arn
}
