##############################################################################
## WORKER SPOT FLEETS
data "template_file" "external_workers_cloud_config" {
  template = file("${path.module}/cloud-init/partials/worker.cfg")

  vars = {
    # Add any variables here to pass to the setup script when the instance
    # boots.
    osbuild_commit  = var.osbuild_commit
    composer_commit = var.composer_commit

    # Change these to worker certs later.
    osbuild_ca_cert = filebase64("${path.module}/files/osbuild-ca-cert.pem")

    # TODO(mhayden): Remove the address below once DNS is working.
    composer_host    = var.composer_host_external
    composer_address = aws_instance.composer_external.private_ip

    # Provide the ARN to the secret that contains keys/certificates
    worker_ssl_keys_arn = data.aws_secretsmanager_secret.internal_worker_keys.arn

    # Provide the ARN to the secret that contains keys/certificates
    subscription_manager_command = data.aws_secretsmanager_secret.subscription_manager_command.arn

    # TODO: pick dns name from the right availability zone
    secrets_manager_endpoint_domain = "secretsmanager.us-east-1.amazonaws.com"

    # Set the hostname of the instance.
    system_hostname_prefix = "${local.workspace_name}-external-worker"
  }
}

# Render a multi-part cloud-init config making use of the part
# above, and other source files
data "template_cloudinit_config" "external_workers_cloud_init" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.external_workers_cloud_config.rendered
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
    content      = file("${path.module}/cloud-init/partials/worker_keys.sh")
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/cloud-init/partials/worker_hosts.sh")
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/cloud-init/partials/worker_service.sh")
  }
}

# Create a launch template that specifies almost everything about our workers.
# This eliminates a lot of repeated code for the actual spot fleet itself.
resource "aws_launch_template" "worker_external_x86" {
  name          = "imagebuilder_worker_external_x86_${local.workspace_name}"
  image_id      = data.aws_ami.rhel8_x86_prebuilt.id
  instance_type = "t3.medium"
  key_name      = "mhayden"

  # Allow the instance to assume the external_worker IAM role.
  iam_instance_profile {
    name = aws_iam_instance_profile.internal_worker.name
  }

  # Assemble the cloud-init userdata file.
  user_data = data.template_cloudinit_config.external_workers_cloud_init.rendered

  # Get the security group for the instances.
  vpc_security_group_ids = [
    aws_security_group.external_workers.id
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
    var.imagebuilder_tags, { Name = "🔧 External Composer Worker (${local.workspace_name})" },
  )

  # Apply tags to the instances created in the fleet.
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.imagebuilder_tags, { Name = "🔧 External Composer Worker (${local.workspace_name})" },
    )
  }

  # Apply tags to the EBS volumes created in the fleet.
  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.imagebuilder_tags, { Name = "🔧 External Composer Worker (${local.workspace_name})" },
    )
  }
}

# Create a spot fleet with our launch template.
resource "aws_spot_fleet_request" "workers_external_x86" {
  # Ensure we use the lowest price instances at all times.
  allocation_strategy = "lowestPrice"

  # Keep the fleet at the target_capacity at all times.
  fleet_type      = "maintain"
  target_capacity = 5

  # IAM role that the spot fleet service can use.
  iam_fleet_role = aws_iam_role.spot_fleet_tagging_role.arn

  # Instances that reach spot expiration or are stopped due to target capacity
  # limits should be terminated.
  terminate_instances_with_expiration = true

  # Create a new fleet before destroying the old one.
  # lifecycle {
  #   create_before_destroy = true
  # }

  # Use our pre-defined launch template.
  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.worker_external_x86.id
      version = aws_launch_template.worker_external_x86.latest_version
    }

    dynamic "overrides" {
      for_each = var.worker_instance_types

      content {
        instance_type = overrides.value
        subnet_id     = data.aws_subnet.external_subnet_primary.id
      }
    }
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "External worker fleet - ${local.workspace_name}" },
  )
}
