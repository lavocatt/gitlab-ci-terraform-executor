# S3 endpoint within our VPC allows us to avoid bandwidth charges to/from S3
# in the same region.
resource "aws_vpc_endpoint" "internal_vpc_s3" {
  vpc_id       = data.aws_vpc.internal_vpc.id
  service_name = "com.amazonaws.us-east-1.s3"

  tags = merge(
    var.imagebuilder_tags,
    {
      Name = "Image Builder S3 VPC endpoint"
    },
  )
}

##############################################################################
## SECURITY GROUPS
# Allow ssh access.
resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH access"
  vpc_id      = data.aws_vpc.internal_vpc.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "allow-ssh" },
  )
}

# Allow ICMP.
resource "aws_security_group" "allow_icmp" {
  name        = "allow-ssh"
  description = "Allow SSH access"
  vpc_id      = data.aws_vpc.internal_vpc.id

  ingress {
    description = "ICMP"
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "allow-icmp" },
  )
}
