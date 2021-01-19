##############################################################################
## INTERNAL COMPOSER DEPLOYMENT

data "template_file" "internal_composer_cloud_config" {
  template = file("${path.module}/cloud-init/partials/composer.cfg")

  vars = {
    # Add any variables here to pass to the setup script when the instance
    # boots.
    osbuild_commit  = var.osbuild_commit
    composer_commit = var.composer_commit
    osbuild_ca_cert = filebase64("${path.module}/files/osbuild-ca-cert.pem")
    composer_cert   = filebase64("${path.module}/cloud-init/composer/composer.cert.pem")

    # Provide the ARN to the secret that contains keys/certificates
    composer_ssl_keys_arn = data.aws_secretsmanager_secret.internal_composer_keys.arn

    # Provide the ARN to the secret that contains keys/certificates
    subscription_manager_command = data.aws_secretsmanager_secret.subscription_manager_command.arn

    # TODO: pick dns name from the right availability zone
    secrets_manager_endpoint_domain = aws_vpc_endpoint.internal_vpc_secretsmanager.dns_entry[0]["dns_name"]

    # Set the hostname of the instance.
    system_hostname_prefix = "${local.workspace_name}-internal-composer"
  }
}

# Render a multi-part cloud-init config making use of the part
# above, and other source files
data "template_cloudinit_config" "internal_composer_cloud_init" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.internal_composer_cloud_config.rendered
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

# Create a network interface with security groups and a static IP address.
# NOTE(mhayden): We must create this network interface separately from the
# aws_instance resources so the network interface is not destroyed and
# re-created repeatedly.
resource "aws_network_interface" "composer_internal" {
  subnet_id = data.aws_subnet.internal_subnet_primary.id

  # Take the 10th IP in the primary internal network block.
  private_ips = [
    cidrhost(data.aws_subnet.internal_subnet_primary.cidr_block, local.network_interface_ip_address_index)
  ]

  # Allow all egress as well as ingress from trusted internal networks.
  security_groups = [
    aws_security_group.internal_allow_egress.id,
    aws_security_group.internal_allow_trusted.id
  ]

  tags = merge(
    var.imagebuilder_tags, { Name = "🏗 Internal Composer (${local.workspace_name})" },
  )

}

# Provision an EBS storage volume for composer's persistent data.
resource "aws_ebs_volume" "composer_internal" {
  availability_zone = data.aws_subnet.internal_subnet_primary.availability_zone

  encrypted = true
  size      = 50
  type      = "gp2"

  tags = merge(
    var.imagebuilder_tags, { Name = "🏗 Internal Composer (${local.workspace_name})" },
  )
}

# Attach the EBS storage volume to the instance.
# NOTE(mhayden): This attachment is critical to ensure the EBS volume is not
# destroyed when the instance is re-provisioned.
resource "aws_volume_attachment" "composer_internal" {
  # Make the device appear as a secondary disk on the instance.
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.composer_internal.id
  instance_id = aws_instance.composer_internal.id
}

# Provision the AWS isntance for composer.
resource "aws_instance" "composer_internal" {
  ami           = data.aws_ami.rhel8_x86_prebuilt.id
  instance_type = "t3.small"

  # Allow the instance to assume the internal_composer IAM role.
  iam_instance_profile = aws_iam_instance_profile.internal_composer.name

  # Pass the user data that we generated.
  user_data_base64 = data.template_cloudinit_config.internal_composer_cloud_init.rendered

  # Attach the network interface with the static IP address as the primary
  # network interface.
  network_interface {
    network_interface_id = aws_network_interface.composer_internal.id
    device_index         = 0
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "🏗 Internal Composer (${local.workspace_name})" },
  )
}
