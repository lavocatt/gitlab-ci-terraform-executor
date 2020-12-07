##############################################################################
## INTERNAL COMPOSER DEPLOYMENT
# Assemble cloud-init user data for the instance.
data "template_file" "composer_internal_user_data" {
  template = file("cloud-init/composer/composer-variables.template")

  vars = {
    # Add any variables here to pass to the setup script when the instance
    # boots.
    osbuild_commit  = var.osbuild_commit
    composer_commit = var.composer_commit
    osbuild_ca_cert = filebase64("${path.module}/files/osbuild-ca-cert.pem")

    # Provide the ARN to the secret that contains keys/certificates
    composer_ssl_keys_arn = data.aws_secretsmanager_secret.internal_composer_keys.arn

    # 💣 Split off most of the setup script to avoid shenanigans with
    # Terraform's template interpretation that destroys Bash variables.
    # https://github.com/hashicorp/terraform/issues/15933
    setup_script = file("cloud-init/composer/composer-setup.sh")
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

  # TODO(mhayden): Remove this key once we know everything is working.
  key_name = "mhayden"

  # Allow the instance to assume the internal_composer IAM role.
  iam_instance_profile = aws_iam_instance_profile.internal_composer.name

  # Pass the user data that we generated.
  user_data = base64encode(data.template_file.composer_internal_user_data.rendered)

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
