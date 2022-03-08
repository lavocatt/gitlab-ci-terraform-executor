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
data "template_file" "workers_fedora_cloud_config" {
  template = file("${path.module}/cloud-init/partials/worker_aoc.cfg")

  vars = {
    # Add any variables here to pass to the setup script when the instance
    # boots.

    composer_host = local.workspace_name == "staging" ? var.composer_host_aoc_staging : var.composer_host_aoc

    # Provide the ARNs to the secrets that contains keys/certificates
    subscription_manager_command          = data.aws_secretsmanager_secret.subscription_manager_command.arn
    gcp_service_account_image_builder_arn = data.aws_secretsmanager_secret.gcp_service_account_image_builder.arn
    azure_account_image_builder_arn       = data.aws_secretsmanager_secret.azure_account_image_builder.arn
    aws_account_image_builder_arn         = data.aws_secretsmanager_secret.aws_account_image_builder.arn
    offline_token_arn                     = data.aws_secretsmanager_secret.offline_token_fedora.arn

    # TODO: pick dns name from the right availability zone
    secrets_manager_endpoint_domain = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
    cloudwatch_logs_endpoint_domain = "logs.${data.aws_region.current.name}.amazonaws.com"

    # Set the hostname of the instance.
    system_hostname_prefix = "${local.workspace_name}-worker-fedora"

    # Set the CloudWatch log group.
    cloudwatch_log_group = "${local.workspace_name}_workers_fedora"
  }
}

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

# Create a launch template that specifies almost everything about our workers.
# This eliminates a lot of repeated code for the actual spot fleet itself.
resource "aws_launch_template" "worker_fedora_x86" {
  name          = "imagebuilder_worker_fedora_x86_${local.workspace_name}"
  image_id      = data.aws_ami.rhel8_x86_prebuilt.id
  instance_type = "t3.medium"
  key_name      = "obudai"

  # Allow the instance to assume the external_worker IAM role.
  iam_instance_profile {
    name = aws_iam_instance_profile.worker_fedora.name
  }

  # Assemble the cloud-init userdata file.
  user_data = base64encode(data.template_file.workers_fedora_cloud_config.rendered)

  # Get the security group for the instances.
  vpc_security_group_ids = [
    aws_security_group.workers_fedora.id
  ]

  # Ensure the latest version of the template is marked as the default one.
  update_default_version = true

  # Block devices attached to each worker.
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 50
      volume_type = "gp2"
      encrypted   = true
    }
  }

  # Apply tags to the spot fleet definition itself.
  tags = merge(
    var.imagebuilder_tags, { Name = "🇫 Fedora Worker (${local.workspace_name})" },
  )

  # Apply tags to the instances created in the fleet.
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.imagebuilder_tags, { Name = "🇫 Fedora Worker (${local.workspace_name})" },
    )
  }

  # Apply tags to the EBS volumes created in the fleet.
  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.imagebuilder_tags, { Name = "🇫 Fedora Worker (${local.workspace_name})" },
    )
  }
}

# Create a auto-scaling group with our launch template.
resource "aws_autoscaling_group" "workers_fedora_x86" {
  name = "imagebuilder_workers_fedora_x86_${local.workspace_name}"

  # For now, specify both minimum and maximum to the same value
  max_size = local.spot_fleet_worker_fedora_count
  min_size = local.spot_fleet_worker_fedora_count

  # Run in all availability zones
  vpc_zone_identifier = data.aws_subnet_ids.external_subnets.ids

  # React faster to price changes
  capacity_rebalance = true

  mixed_instances_policy {
    instances_distribution {
      # Ensure we use the lowest price instances at all times.
      spot_allocation_strategy = "lowest-price"

      # We want only spot instances
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.worker_fedora_x86.id
        version            = aws_launch_template.worker_fedora_x86.latest_version
      }

      dynamic "override" {
        for_each = var.worker_instance_types

        content {
          instance_type = override.value
        }
      }
    }
  }
  # ASG doesn't refresh instances when a launch template is changed,
  # therefore we must explicitly request a refresh.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      # Wait for 5 minutes before the instance is configured
      instance_warmup = "300"

      # We always must have 80% of healthy instances
      min_healthy_percentage = 80
    }
  }

  dynamic "tag" {
    for_each = var.imagebuilder_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Name"
    value               = "🇫 Fedora Worker ${local.workspace_name}"
    propagate_at_launch = true
  }
}
