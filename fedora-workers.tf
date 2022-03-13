# Create a policy that lets EC2 assume the role.
data "aws_iam_policy_document" "infrastructure_ec2_principal_fedora" {
  statement {
    sid = "AllowEC2AssumeRole"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Create role for the fedora workers to use
resource "aws_iam_role" "worker_fedora" {
  name = "workers_fedora_${local.workspace_name}"

  assume_role_policy = data.aws_iam_policy_document.infrastructure_ec2_principal_fedora.json

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder fedora worker role - ${local.workspace_name}" },
  )
}

# Link instance profiles to the roles.
resource "aws_iam_instance_profile" "worker_fedora" {
  name = "worker_fedora_${local.workspace_name}"
  role = aws_iam_role.worker_fedora.name
}

# Create policies that allows for reading secrets.
data "aws_iam_policy_document" "worker_fedora_read_keys" {
  statement {
    sid = "WorkerReadSecrets"

    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      data.aws_secretsmanager_secret.offline_token_fedora.arn,
      data.aws_secretsmanager_secret.subscription_manager_command.arn,
      data.aws_secretsmanager_secret.gcp_service_account_image_builder.arn,
      data.aws_secretsmanager_secret.azure_account_image_builder.arn,
      data.aws_secretsmanager_secret.aws_account_image_builder.arn
    ]
  }
}

# Load the external secrets policies.
resource "aws_iam_policy" "worker_fedora_read_keys" {
  name   = "worker_fedora_read_keys_${local.workspace_name}"
  policy = data.aws_iam_policy_document.worker_fedora_read_keys.json
}

# Attach the external secrets policies to the external worker and composer roles.
resource "aws_iam_role_policy_attachment" "worker_fedora_read_keys" {
  role       = aws_iam_role.worker_fedora.name
  policy_arn = aws_iam_policy.worker_fedora_read_keys.arn
}

# Create a policy that allows external composer/workers to send log data to
# cloudwatch.
data "aws_iam_policy_document" "cloudwatch_logging_fedora" {
  statement {
    sid = "BasicCloudWatchUsage"

    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeVolumes",
      "ec2:DescribeTags",
    ]

    resources = ["*"]
  }

  # vector healthcheck needs this
  statement {
    sid = "CloudWatchDescribeLogGroups"
    actions = [
      "logs:DescribeLogGroups",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.identity.account_id}:log-group:*"
    ]
  }

  statement {
    sid = "CloudWatchDescribeLogStreams"

    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:CreateLogStream",
    ]

    resources = [
      "${aws_cloudwatch_log_group.workers_fedora.arn}:*"
    ]
  }
}

# Load the CloudWatch policy.
resource "aws_iam_policy" "cloudwatch_logging_fedora" {
  name   = "cloudwatch_logging_fedora_${local.workspace_name}"
  policy = data.aws_iam_policy_document.cloudwatch_logging_fedora.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_worker_fedora" {
  role       = aws_iam_role.worker_fedora.name
  policy_arn = aws_iam_policy.cloudwatch_logging_fedora.arn
}

# Attach the monitoring client policy.
resource "aws_iam_role_policy_attachment" "pozorbot_worker_fedora" {
  role       = aws_iam_role.worker_fedora.name
  policy_arn = aws_iam_policy.pozorbot_client_sqs.arn
}

##############################################################################
## FEDORA COMPOSER SYSLOG
# Create a log group that can contain multiple streams.
resource "aws_cloudwatch_log_group" "workers_fedora" {
  name = "${local.workspace_name}_workers_fedora"

  tags = merge(
    var.imagebuilder_tags, { Name = "Workers log group for Fedora for ${local.workspace_name}" },
  )
}


##############################################################################
## WORKER SPOT FLEETS

# Security group for fedora worker instances.
resource "aws_security_group" "workers_fedora" {
  name        = "workers_fedora_${local.workspace_name}"
  description = "Fedora workers"
  vpc_id      = data.aws_vpc.external_vpc.id

  # Allow all ICMP traffic.
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH traffic.
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all egress traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "workers_fedora_${local.workspace_name}" },
  )
}

data "aws_ami" "worker_fedora_35_x86_64" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "tag:composer_commit"
    values = [var.fedora_workers_composer_commit]
  }
  filter {
    name   = "tag:os"
    values = ["fedora"]
  }
  filter {
    name   = "tag:os_version"
    values = ["35"]
  }
  filter {
    name   = "tag:arch"
    values = ["x86_64"]
  }
}


module "worker_group_fedora_35_x86_64" {
  source = "./worker-group"

  name = "Fedora-Worker-x86_64-(${local.workspace_name})"

  composer_host        = local.workspace_name == "staging" ? var.composer_host_aoc_staging : var.composer_host_aoc
  image_id             = data.aws_ami.worker_fedora_35_x86_64.id
  instance_profile_arn = aws_iam_instance_profile.worker_fedora.arn
  instance_types       = ["c6a.large"]
  max_size             = 1
  min_size             = 1
  offline_token_arn    = data.aws_secretsmanager_secret.offline_token_fedora.arn
  security_group_id    = aws_security_group.workers_fedora.id
  subnet_ids           = data.aws_subnet_ids.external_subnets.ids
  workspace_name       = local.workspace_name

  cloudwatch_log_group = aws_cloudwatch_log_group.workers_fedora.name
}

data "aws_ami" "worker_fedora_35_aarch64" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "tag:composer_commit"
    values = [var.fedora_workers_composer_commit]
  }
  filter {
    name   = "tag:os"
    values = ["fedora"]
  }
  filter {
    name   = "tag:os_version"
    values = ["35"]
  }
  filter {
    name   = "tag:arch"
    values = ["aarch64"]
  }
}

module "worker_group_fedora_35_aarch64" {
  source = "./worker-group"

  name = "Fedora-Worker-aarch64-(${local.workspace_name})"

  composer_host        = local.workspace_name == "staging" ? var.composer_host_aoc_staging : var.composer_host_aoc
  image_id             = data.aws_ami.worker_fedora_35_aarch64.id
  instance_profile_arn = aws_iam_instance_profile.worker_fedora.arn
  instance_types       = ["c6g.large"]
  max_size             = 1
  min_size             = 1
  offline_token_arn    = data.aws_secretsmanager_secret.offline_token_fedora.arn
  security_group_id    = aws_security_group.workers_fedora.id
  subnet_ids           = data.aws_subnet_ids.external_subnets.ids
  workspace_name       = local.workspace_name

  cloudwatch_log_group = aws_cloudwatch_log_group.workers_fedora.name
}
