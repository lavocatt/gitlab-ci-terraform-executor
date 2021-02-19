##############################################################################
## EXTERNAL COMPOSER DEPLOYMENT
data "template_file" "external_composer_cloud_config" {
  template = file("${path.module}/cloud-init/partials/composer.cfg")

  vars = {
    # Add any variables here to pass to the setup script when the instance
    # boots.
    osbuild_commit  = var.osbuild_commit
    composer_commit = var.composer_commit
    osbuild_ca_cert = filebase64("${path.module}/files/osbuild-ca-cert.pem")

    # Provide the ARN to the secret that contains keys/certificates
    composer_ssl_keys_arn = data.aws_secretsmanager_secret.external_composer_keys.arn

    # Provide the ARN to the secret that contains keys/certificates
    subscription_manager_command = data.aws_secretsmanager_secret.subscription_manager_command.arn

    # TODO: pick dns name from the right availability zone
    secrets_manager_endpoint_domain = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
    cloudwatch_logs_endpoint_domain = "logs.${data.aws_region.current.name}.amazonaws.com"

    # Set the hostname of the instance.
    system_hostname_prefix = "${local.workspace_name}-external-composer"

    # Set the CloudWatch log group.
    cloudwatch_log_group = "${local.workspace_name}_external"
  }
}

# Render a multi-part cloud-init config making use of the part
# above, and other source files
data "template_cloudinit_config" "external_composer_cloud_init" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.external_composer_cloud_config.rendered
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
    content      = file("${path.module}/cloud-init/partials/composer_keys.sh")
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/cloud-init/partials/composer_storage.sh")
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/cloud-init/partials/composer_service.sh")
  }
}

# Set up an elastic IP address for the network interface to ensure that the
# public IP address does not change between deployments.
resource "aws_eip" "lb" {
  network_interface = aws_network_interface.composer_external.id
  vpc               = true

  tags = merge(
    var.imagebuilder_tags, { Name = "🏗 External Composer (${local.workspace_name})" },
  )
}

# Create a network interface with security groups and a static IP address.
# NOTE(mhayden): We must create this network interface separately from the
# aws_instance resources so the network interface is not destroyed and
# re-created repeatedly.
resource "aws_network_interface" "composer_external" {
  subnet_id = data.aws_subnet.external_subnet_primary.id

  # Take the 10th IP in the primary external network block.
  private_ips = [
    cidrhost(data.aws_subnet.external_subnet_primary.cidr_block, local.network_interface_ip_address_index)
  ]

  # Allow all egress as well as ingress from trusted external networks.
  security_groups = [
    aws_security_group.external_composer.id
  ]

  tags = merge(
    var.imagebuilder_tags, { Name = "🏗 External Composer (${local.workspace_name})" },
  )

}

# Provision an EBS storage volume for composer's persistent data.
resource "aws_ebs_volume" "composer_external" {
  availability_zone = data.aws_subnet.external_subnet_primary.availability_zone

  encrypted = true
  size      = 50
  type      = "gp2"

  tags = merge(
    var.imagebuilder_tags, { Name = "🏗 External Composer (${local.workspace_name})" },
  )
}

# Attach the EBS storage volume to the instance.
# NOTE(mhayden): This attachment is critical to ensure the EBS volume is not
# destroyed when the instance is re-provisioned.
resource "aws_volume_attachment" "composer_external" {
  # Make the device appear as a secondary disk on the instance.
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.composer_external.id
  instance_id = aws_instance.composer_external.id
}

# Provision the AWS isntance for composer.
resource "aws_instance" "composer_external" {
  ami           = data.aws_ami.rhel8_x86_prebuilt.id
  instance_type = "t3.small"

  # Allow the instance to assume the external IAM role.
  iam_instance_profile = aws_iam_instance_profile.external_composer.name

  # Pass the user data that we generated.
  user_data_base64 = data.template_cloudinit_config.external_composer_cloud_init.rendered

  # Attach the network interface with the static IP address as the primary
  # network interface.
  network_interface {
    network_interface_id = aws_network_interface.composer_external.id
    device_index         = 0
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "🏗 External Composer (${local.workspace_name})" },
  )
}
