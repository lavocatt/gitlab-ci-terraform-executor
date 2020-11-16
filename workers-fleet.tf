# Set up the cloud-init user data for worker instances.
data "template_file" "worker_user_data" {
  template = file("cloud-init/worker-variables.template")

  vars = {
    # Add any variables here to pass to the setup script when the instance
    # boots.
    node_hostname = "worker-fleet-testing"

    # 💣 Split off most of the setup script to avoid shenanigans with
    # Terraform's template interpretation that destroys Bash variables.
    # https://github.com/hashicorp/terraform/issues/15933
    setup_script = file("cloud-init/worker-setup.sh")
  }
}

# Create a launch template that specifies almost everything about our workers.
# This eliminates a lot of repeated code for the actual spot fleet itself.
resource "aws_launch_template" "worker_x86" {
  name          = "imagebuilder-worker-x86"
  image_id      = data.aws_ami.rhel8_x86.id
  instance_type = "t3.medium"
  key_name      = "mhayden"

  # NOTE(mhayden): We will use instance roles later as part of COMPOSER-685.
  #   iam_instance_profile {
  #     name = "imagebuilder-worker-role"
  #   }

  # Assemble the cloud-init userdata file.
  user_data = base64encode(data.template_file.worker_user_data.rendered)

  # Get the security group for the instances.
  vpc_security_group_ids = [
    aws_security_group.allow_icmp.id,
    aws_security_group.allow_ssh.id
  ]

  # Ensure the latest version of the template is marked as the default one.
  update_default_version = true

  # Block devices attached to each worker.
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 50
      volume_type = "gp2"
    }

  }

  # Apply tags to the spot fleet definition itself.
  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder worker" },
  )

  # Apply tags to the instances created in the fleet.
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.imagebuilder_tags, { Name = "Image Builder worker" },
    )
  }

  # Apply tags to the EBS volumes created in the fleet.
  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.imagebuilder_tags, { Name = "Image Builder worker" },
    )
  }
}

# Create a spot fleet with our launch template.
resource "aws_spot_fleet_request" "imagebuilder_worker_x86" {
  # Ensure we use the lowest price instances at all times.
  allocation_strategy = "lowestPrice"

  # Keep the fleet at the target_capacity at all times.
  fleet_type      = "maintain"
  target_capacity = 1

  # IAM role that the spot fleet service can use.
  iam_fleet_role = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-ec2-spot-fleet-tagging-role"

  # Instances that reach spot expiration or are stopped due to target capacity
  # limits should be terminated.
  terminate_instances_with_expiration = true

  # Create a new fleet before destroying the old one.
  lifecycle {
    create_before_destroy = true
  }

  # Use our pre-defined launch template.
  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.worker_x86.id
      version = aws_launch_template.worker_x86.latest_version
    }

    dynamic "overrides" {
      for_each = var.worker_instance_types

      content {
        instance_type = overrides.value
        subnet_id     = sort(data.aws_subnet_ids.internal_subnets.ids)[0]
      }
    }
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder worker fleet" },
  )
}
