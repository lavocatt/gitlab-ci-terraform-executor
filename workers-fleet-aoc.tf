##############################################################################
## WORKER SPOT FLEETS
data "template_file" "workers_aoc_cloud_config" {
  template = file("${path.module}/cloud-init/partials/worker_aoc.cfg")

  vars = {
    # Add any variables here to pass to the setup script when the instance
    # boots.
    osbuild_commit  = var.osbuild_commit
    composer_commit = var.composer_commit

    composer_host = local.workspace_name == "staging" ? var.composer_host_aoc_staging : var.composer_host_aoc

    # Provide the ARNs to the secrets that contains keys/certificates
    subscription_manager_command          = data.aws_secretsmanager_secret.subscription_manager_command.arn
    gcp_service_account_image_builder_arn = data.aws_secretsmanager_secret.gcp_service_account_image_builder.arn
    azure_account_image_builder_arn       = data.aws_secretsmanager_secret.azure_account_image_builder.arn
    aws_account_image_builder_arn         = data.aws_secretsmanager_secret.aws_account_image_builder.arn
    offline_token_arn                     = data.aws_secretsmanager_secret.offline_token.arn

    # TODO: pick dns name from the right availability zone
    secrets_manager_endpoint_domain = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
    cloudwatch_logs_endpoint_domain = "logs.${data.aws_region.current.name}.amazonaws.com"

    # Set the hostname of the instance.
    system_hostname_prefix = "${local.workspace_name}-worker-aoc"

    # Set the CloudWatch log group.
    cloudwatch_log_group = "${local.workspace_name}_workers_aoc"
  }
}

# Render a multi-part cloud-init config making use of the part
# above, and other source files
data "template_cloudinit_config" "workers_aoc_cloud_init" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.workers_aoc_cloud_config.rendered
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/cloud-init/partials/set_hostname.sh")
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/cloud-init/partials/subscription_manager.sh")
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/cloud-init/partials/worker_external_creds.sh")
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/cloud-init/partials/worker_service.sh")
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/cloud-init/partials/offline_token.sh")
  }
}

# Create a launch template that specifies almost everything about our workers.
# This eliminates a lot of repeated code for the actual spot fleet itself.
resource "aws_launch_template" "worker_aoc_x86" {
  name          = "imagebuilder_worker_aoc_x86_${local.workspace_name}"
  image_id      = data.aws_ami.rhel8_x86_prebuilt.id
  instance_type = "t3.medium"

  # Allow the instance to assume the external_worker IAM role.
  iam_instance_profile {
    name = aws_iam_instance_profile.worker_aoc.name
  }

  # Assemble the cloud-init userdata file.
  user_data = data.template_cloudinit_config.workers_aoc_cloud_init.rendered

  # Get the security group for the instances.
  vpc_security_group_ids = [
    aws_security_group.workers_aoc.id
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
    var.imagebuilder_tags, { Name = "🔧 AOC Worker (${local.workspace_name})" },
  )

  # Apply tags to the instances created in the fleet.
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.imagebuilder_tags, { Name = "🔧 AOC Worker (${local.workspace_name})" },
    )
  }

  # Apply tags to the EBS volumes created in the fleet.
  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.imagebuilder_tags, { Name = "🔧 AOC Worker (${local.workspace_name})" },
    )
  }
}

# Create a auto-scaling group with our launch template.
resource "aws_autoscaling_group" "workers_aoc_x86" {
  name = "imagebuilder_workers_aoc_x86_${local.workspace_name}"

  # For now, specify both minimum and maximum to the same value
  max_size = local.spot_fleet_worker_aoc_count
  min_size = local.spot_fleet_worker_aoc_count

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
        launch_template_id = aws_launch_template.worker_aoc_x86.id
      }

      dynamic "override" {
        for_each = var.worker_instance_types

        content {
          instance_type = override.value
        }
      }
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
    value               = "Worker ASG for aoc - ${local.workspace_name}"
    propagate_at_launch = true
  }
}
