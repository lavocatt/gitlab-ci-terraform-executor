##############################################################################
## VPC
# S3 endpoint within our VPC allows us to avoid bandwidth charges to/from S3
# in the same region.
resource "aws_vpc_endpoint" "internal_vpc_s3" {
  vpc_id       = data.aws_vpc.internal_vpc.id
  service_name = "com.amazonaws.us-east-1.s3"

  tags = merge(
    var.imagebuilder_tags, { Name = "📦 S3 VPC endpoint (internal)" },
  )
}
resource "aws_vpc_endpoint" "external_vpc_s3" {
  vpc_id       = data.aws_vpc.external_vpc.id
  service_name = "com.amazonaws.us-east-1.s3"

  tags = merge(
    var.imagebuilder_tags, { Name = "📦 S3 VPC endpoint (external)" },
  )
}

# CloudWatch Logs endpoint enables us to access CloudWatch Logs from
# the internal network and to avoid bandwidth charges.
resource "aws_vpc_endpoint" "internal_vpc_cloudwatch_logs" {
  vpc_id              = data.aws_vpc.internal_vpc.id
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.internal_allow_egress.id,
    aws_security_group.internal_allow_trusted.id
  ]

  tags = merge(
    var.imagebuilder_tags, { Name = "📜 CloudWatch Logs VPC endpoint (internal)" },
  )
}
resource "aws_vpc_endpoint" "external_vpc_cloudwatch_logs" {
  vpc_id              = data.aws_vpc.external_vpc.id
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.internal_allow_egress.id,
    aws_security_group.internal_allow_trusted.id
  ]

  tags = merge(
    var.imagebuilder_tags, { Name = "📜 CloudWatch Logs VPC endpoint (external)" },
  )
}

# Endpoint to reach AWS Secrets Manager.
resource "aws_vpc_endpoint" "internal_vpc_secretsmanager" {
  vpc_id              = data.aws_vpc.internal_vpc.id
  service_name        = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.internal_allow_egress.id,
    aws_security_group.internal_allow_trusted.id
  ]

  tags = merge(
    var.imagebuilder_tags, { Name = "🤫 Secrets Manager VPC endpoint (internal)" },
  )
}
resource "aws_vpc_endpoint" "external_vpc_secretsmanager" {
  vpc_id              = data.aws_vpc.external_vpc.id
  service_name        = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.internal_allow_egress.id,
    aws_security_group.internal_allow_trusted.id
  ]

  tags = merge(
    var.imagebuilder_tags, { Name = "🤫 Secrets Manager VPC endpoint (external)" },
  )
}

##############################################################################
## PUBLIC SECURITY GROUPS
# Allow ssh access.
resource "aws_security_group" "allow_ssh" {
  name        = "external_allow_ssh_${local.workspace_name}"
  description = "Allow SSH access"
  vpc_id      = data.aws_vpc.external_vpc.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "external_allow_ssh_${local.workspace_name}" },
  )
}

# Allow ICMP.
resource "aws_security_group" "allow_icmp" {
  name        = "external_allow_icmp_${local.workspace_name}"
  description = "Allow ICMP access"
  vpc_id      = data.aws_vpc.external_vpc.id

  ingress {
    description = "ICMP"
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "external_allow_icmp_${local.workspace_name}" },
  )
}

# Allow egress.
resource "aws_security_group" "allow_egress" {
  name        = "external_allow_egress_${local.workspace_name}"
  description = "Allow egress traffic"
  vpc_id      = data.aws_vpc.external_vpc.id

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
    var.imagebuilder_tags, { Name = "external_allow_egress_${local.workspace_name}" },
  )
}

##############################################################################
## INTERNAL SECURITY GROUPS
# Allow egress.
resource "aws_security_group" "internal_allow_egress" {
  name        = "internal_allow_egress_${local.workspace_name}"
  description = "Allow egress traffic"
  vpc_id      = data.aws_vpc.internal_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "internal_allow_egress_${local.workspace_name}" },
  )
}

# Allow ingress from internal networks.
resource "aws_security_group" "internal_allow_trusted" {
  name        = "internal_allow_trusted_${local.workspace_name}"
  description = "Allow trusted access"
  vpc_id      = data.aws_vpc.internal_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "internal_allow_trusted_${local.workspace_name}" },
  )
}
