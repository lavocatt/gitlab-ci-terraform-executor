// create policy that allows splunk to collect data from our AWS account
data "aws_iam_policy_document" "splunk_collect_data" {
  statement {
    actions = [
      "apigateway:GET",
      "autoscaling:DescribeAutoScalingGroups",
      "cloudformation:ListResources",
      "cloudformation:GetResource",
      "cloudfront:GetDistributionConfig",
      "cloudfront:ListDistributions",
      "cloudfront:ListTagsForResource",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "directconnect:DescribeConnections",
      "dynamodb:DescribeTable",
      "dynamodb:ListTables",
      "dynamodb:ListTagsOfResource",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeNatGateways",
      "ec2:DescribeRegions",
      "ec2:DescribeReservedInstances",
      "ec2:DescribeReservedInstancesModifications",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:ListClusters",
      "ecs:ListServices",
      "ecs:ListTagsForResource",
      "ecs:ListTaskDefinitions",
      "ecs:ListTasks",
      "eks:DescribeCluster",
      "eks:ListClusters",
      "elasticache:DescribeCacheClusters",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticmapreduce:DescribeCluster",
      "elasticmapreduce:ListClusters",
      "es:DescribeElasticsearchDomain",
      "es:ListDomainNames",
      "kinesis:DescribeStream",
      "kinesis:ListShards",
      "kinesis:ListStreams",
      "kinesis:ListTagsForStream",
      "kinesisanalytics:ListApplications",
      "kinesisanalytics:DescribeApplication",
      "lambda:GetAlias",
      "lambda:ListFunctions",
      "lambda:ListTags",
      "logs:DeleteSubscriptionFilter",
      "logs:DescribeLogGroups",
      "logs:DescribeSubscriptionFilters",
      "logs:PutSubscriptionFilter",
      "organizations:DescribeOrganization",
      "rds:DescribeDBInstances",
      "rds:DescribeDBClusters",
      "rds:ListTagsForResource",
      "redshift:DescribeClusters",
      "redshift:DescribeLoggingStatus",
      "s3:GetBucketLocation",
      "s3:GetBucketLogging",
      "s3:GetBucketNotification",
      "s3:GetBucketTagging",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "s3:PutBucketNotification",
      "sqs:GetQueueAttributes",
      "sqs:ListQueues",
      "sqs:ListQueueTags",
      "states:ListActivities",
      "states:ListStateMachines",
      "tag:GetResources",
      "workspaces:DescribeWorkspaces"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "splunk_collect_data" {
  name   = "splunk_collect_data"
  policy = data.aws_iam_policy_document.splunk_collect_data.json

  # deploy only in staging
  count = local.workspace_name == "staging" ? 1 : 0
}

// create a policy for Splunk's AWS account so it can access our account
data "aws_iam_policy_document" "splunk_principal" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["562691491210"]
    }

    condition {
      test     = "StringEquals"
      values   = ["fsnqdfvmuoelupbjcizk"]
      variable = "sts:ExternalId"
    }
  }
}

// create the role that Splunk will use...
resource "aws_iam_role" "splunk_collect_data" {
  name = "splunk_collect_data"

  assume_role_policy = data.aws_iam_policy_document.splunk_principal.json

  # deploy only in staging
  count = local.workspace_name == "staging" ? 1 : 0
}


// ... and allow it to collect data
resource "aws_iam_role_policy_attachment" "splunk_collect_data" {
  role       = aws_iam_role.splunk_collect_data[0].name
  policy_arn = aws_iam_policy.splunk_collect_data[0].arn

  # deploy only in staging
  count = local.workspace_name == "staging" ? 1 : 0
}
