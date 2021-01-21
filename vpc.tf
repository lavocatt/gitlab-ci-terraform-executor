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
  vpc_id            = data.aws_vpc.internal_vpc.id
  service_name      = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.internal_allow_egress.id,
    aws_security_group.internal_allow_trusted.id
  ]

  subnet_ids = data.aws_subnet_ids.internal_subnets.ids

  tags = merge(
    var.imagebuilder_tags, { Name = "📜 CloudWatch Logs VPC endpoint (internal)" },
  )
}
resource "aws_vpc_endpoint" "external_vpc_cloudwatch_logs" {
  vpc_id            = data.aws_vpc.external_vpc.id
  service_name      = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.external_vpc_endpoints.id
  ]

  subnet_ids = data.aws_subnet_ids.external_subnets.ids

  tags = merge(
    var.imagebuilder_tags, { Name = "📜 CloudWatch Logs VPC endpoint (external)" },
  )
}

# Endpoint to reach AWS Secrets Manager.
resource "aws_vpc_endpoint" "internal_vpc_secretsmanager" {
  vpc_id            = data.aws_vpc.internal_vpc.id
  service_name      = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.internal_allow_egress.id,
    aws_security_group.internal_allow_trusted.id
  ]

  subnet_ids = data.aws_subnet_ids.internal_subnets.ids

  tags = merge(
    var.imagebuilder_tags, { Name = "🤫 Secrets Manager VPC endpoint (internal)" },
  )
}
resource "aws_vpc_endpoint" "external_vpc_secretsmanager" {
  vpc_id            = data.aws_vpc.external_vpc.id
  service_name      = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.external_vpc_endpoints.id
  ]

  subnet_ids = data.aws_subnet_ids.external_subnets.ids

  tags = merge(
    var.imagebuilder_tags, { Name = "🤫 Secrets Manager VPC endpoint (external)" },
  )
}

##############################################################################
## PUBLIC SECURITY GROUPS
# Set up a security group for VPC endpoints which require an interface.
resource "aws_security_group" "external_vpc_endpoints" {
  name        = "external_vpc_endpoints_${local.workspace_name}"
  description = "Allow ingress traffic"
  vpc_id      = data.aws_vpc.external_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
    var.imagebuilder_tags, { Name = "external_vpc_endpoints_${local.workspace_name}" },
  )
}

# Security group for composer instances.
resource "aws_security_group" "external_composer" {
  name        = "external_composer_${local.workspace_name}"
  description = "External composer"
  vpc_id      = data.aws_vpc.external_vpc.id

  # NOTE(mhayden): Temporary access for me and obudai to ensure everything works. 😜
  ingress {
    description = "ssh for mhayden"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["173.174.129.23/32", "185.185.130.88/32"]
  }

  # Allow all ICMP traffic.
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Use the non-standard port for access to osbuild-composer's API.
  ingress {
    description = "osbuild-composer API"
    from_port   = 9876
    to_port     = 9876
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow connections from remote workers.
  ingress {
    description = "remote worker connection"
    from_port   = 8700
    to_port     = 8700
    protocol    = "tcp"
    security_groups = [
      aws_security_group.external_workers.id
    ]
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
    var.imagebuilder_tags, { Name = "external_composer_${local.workspace_name}" },
  )
}

# Security group for worker instances.
resource "aws_security_group" "external_workers" {
  name        = "external_workers_${local.workspace_name}"
  description = "External workers"
  vpc_id      = data.aws_vpc.external_vpc.id

  # NOTE(mhayden): Temporary access for me to ensure everything works. 😜
  ingress {
    description = "ssh for mhayden"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["173.174.129.23/32"]
  }

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
    var.imagebuilder_tags, { Name = "external_workers_${local.workspace_name}" },
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
