data "template_file" "composer_brew_user_data" {
  template = file("cloud-init/composer-brew/composer-variables.template")

  vars = {
    # Add any variables here to pass to the setup script when the instance
    # boots.
    commit = var.composer_commit

    # 💣 Split off most of the setup script to avoid shenanigans with
    # Terraform's template interpretation that destroys Bash variables.
    # https://github.com/hashicorp/terraform/issues/15933
    setup_script = file("cloud-init/composer-brew/composer-setup.sh")
  }
}

resource "aws_ebs_volume" "composer_brew" {
  availability_zone = data.aws_subnet.internal_subnet_primary.availability_zone
  encrypted         = true
  size              = 50
  type              = "gp2"

  tags = merge(
    var.imagebuilder_tags, { Name = "Composer for Brew" },
  )
}

resource "aws_volume_attachment" "composer_brew" {
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.composer_brew.id
  instance_id = aws_instance.composer_brew.id
}

resource "aws_instance" "composer_brew" {
  ami           = data.aws_ami.rhel8_x86.id
  instance_type = "t3.small"
  key_name      = "mhayden"

  vpc_security_group_ids = [
    aws_security_group.internal_allow_egress.id,
    aws_security_group.internal_allow_trusted.id
  ]
  subnet_id = data.aws_subnet.internal_subnet_primary.id
  user_data = base64encode(data.template_file.composer_brew_user_data.rendered)

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "Composer for Brew" },
  )
}

resource "aws_eip" "composer_brew" {
  instance = aws_instance.composer_brew.id
  vpc      = true
}
