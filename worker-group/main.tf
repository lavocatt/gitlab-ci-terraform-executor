terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.72.0"
    }
  }
}


locals {
  cloud_init_user_data = templatefile("${path.module}/user-data.yaml", {
    composer_host = var.composer_host

    # Provide the ARNs to the secrets that contains keys/certificates
    offline_token_arn              = var.offline_token_arn
    subscription_manager_command   = var.subscription_manager_command_arn
    koji_account_image_builder_arn = var.koji_account_image_builder_arn

    # TODO: pick dns name from the right availability zone}
    secrets_manager_endpoint_domain = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
    cloudwatch_logs_endpoint_domain = "logs.${data.aws_region.current.name}.amazonaws.com"

    # Set the hostname of the instance.
    system_hostname_prefix = var.name

    # Set the CloudWatch log group.
    cloudwatch_log_group = var.cloudwatch_log_group

    # unused
    gcp_service_account_image_builder_arn = ""
    azure_account_image_builder_arn       = ""
    aws_account_image_builder_arn         = ""
  })
}

# Create a launch template that specifies almost everything about our workers.
# This eliminates a lot of repeated code for the actual spot fleet itself.
resource "aws_launch_template" "worker" {
  name          = var.name
  image_id      = var.image_id
  instance_type = "t3.medium"
  key_name      = var.key_name

  # Allow the instance to assume the external_worker IAM role.
  iam_instance_profile {
    arn = var.instance_profile_arn
  }

  # Assemble the cloud-init userdata file.
  user_data = base64encode(local.cloud_init_user_data)

  # Get the security group for the instances.
  vpc_security_group_ids = [
    var.security_group_id
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
  tags = {
    Name = var.name
  }

  # Apply tags to the instances created in the fleet.
  tag_specifications {
    resource_type = "instance"

    tags = { Name = var.name }
  }

  # Apply tags to the EBS volumes created in the fleet.
  tag_specifications {
    resource_type = "volume"

    tags = { Name = var.name }
  }
}

# Create a auto-scaling group with our launch template.
resource "aws_autoscaling_group" "workers" {
  name = var.name

  # For now, specify both minimum and maximum to the same value
  max_size = var.max_size
  min_size = var.min_size

  # Run in all availability zones
  vpc_zone_identifier = var.subnet_ids

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
        launch_template_id = aws_launch_template.worker.id
        version            = aws_launch_template.worker.latest_version
      }

      dynamic "override" {
        for_each = var.instance_types

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

  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }
}
