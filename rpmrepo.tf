##############################################################################
## RPMrepo
#
# This file defines most of the resources needed by the RPMrepo snapshot
# infrastructure. It currently uses the following setup:
#
#   * A dedicated S3 bucket called `rpmrepo-storage`, which has public and
#     private data with an attached IAM policy.
#
#   * The VPC Endpoint Interface for S3 is used to provide access to RH-private
#     data in the S3 bucket.
#
#   * An AWS API Gateway proxy integration with AWS Lambda backend which
#     implements the REST API of RPMrepo.
#
#   * An AWS Batch compute environment and job definition to execute snapshot
#     operations.
#
# Apart from the resources defined here, a set of manually configured resources
# is required:
#
# (For these, make sure to include the `AppCode` and `ServiceOwner` tags.)
#
#   * An S3 bucket called `rpmrepo-external` must be created and accessible by
#     this account. The AWS Lambda sources are fetched from it, as well as
#     other static external input. The bucket cannot be created by terraform
#     because its content must be populated for other terraform resources to
#     be created.
#
#   * The AWS API Gateway does not attach a custom domain name, because this
#     account currently cannot validate ACM-based certificates. Therefore, you
#     have to manually create an ACM certificate for `*.osbuild.org.`, validate
#     it via DNS, and wait for the validation to finish. Then you can add it
#     as custom domain to API Gateway and create an API-mapping from the `v1`
#     stage with the `v1` path. Note that you must also point the
#     `rpmrepo.osbuild.org` domain with a CNAME to the endpoint URL of the
#     custom-domain API-Gateway entry (this is different to the endpoint URL
#     of your actual API-Gateway deployment).
#

##############################################################################
## Configuration

variable "rpmrepo_external_bucket" {
  type        = string
  description = "The name of the RPMrepo configuration bucket."
}

variable "rpmrepo_gateway_commit" {
  type        = string
  description = "The git SHA of the RPMrepo gateway to deploy."
}

##############################################################################
## S3 Storage

resource "aws_s3_bucket" "rpmrepo_s3" {
  acl    = "private"
  bucket = "rpmrepo-storage"
  tags = merge(
    var.imagebuilder_tags,
    { Name = "RPMrepo Storage" },
  )
}

data "aws_iam_policy_document" "rpmrepo_s3" {
  statement {
    actions = [
      "s3:GetObject",
    ]
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      "${aws_s3_bucket.rpmrepo_s3.arn}/data/public/*",
      "${aws_s3_bucket.rpmrepo_s3.arn}/data/ref/*",
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
    ]
    condition {
      test     = "StringEquals"
      values   = [aws_vpc_endpoint.internal_vpc_rpmrepo.id]
      variable = "aws:SourceVpce"
    }
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      "${aws_s3_bucket.rpmrepo_s3.arn}/data/rhvpn/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "rpmrepo_s3" {
  bucket = aws_s3_bucket.rpmrepo_s3.id
  policy = data.aws_iam_policy_document.rpmrepo_s3.json
}

##############################################################################
## API Gateway

data "aws_iam_policy_document" "rpmrepo_gateway_lambda" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rpmrepo_gateway_lambda" {
  assume_role_policy = data.aws_iam_policy_document.rpmrepo_gateway_lambda.json
  name               = "rpmrepo-gateway-lambda"
  tags = merge(
    var.imagebuilder_tags,
    { Name = "RPMrepo Gateway Lambda Role" },
  )
}

resource "aws_lambda_function" "rpmrepo_gateway" {
  function_name = "rpmrepo-gateway"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.rpmrepo_gateway_lambda.arn
  runtime       = "python3.8"
  s3_bucket     = var.rpmrepo_external_bucket
  s3_key        = "code/rpmrepo-gateway/rpmrepo-gateway-${var.rpmrepo_gateway_commit}.zip"
  tags = merge(
    var.imagebuilder_tags,
    { Name = "RPMrepo Gateway" },
  )
}

resource "aws_api_gateway_rest_api" "rpmrepo_gateway" {
  name        = "rpmrepo-gateway"
  description = "RPMrepo Web Gateway"
  tags = merge(
    var.imagebuilder_tags,
    { Name = "RPMrepo Gateway" },
  )
}

resource "aws_api_gateway_resource" "rpmrepo_gateway_proxy" {
  rest_api_id = aws_api_gateway_rest_api.rpmrepo_gateway.id
  parent_id   = aws_api_gateway_rest_api.rpmrepo_gateway.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "rpmrepo_gateway_proxy" {
  authorization = "NONE"
  http_method   = "ANY"
  resource_id   = aws_api_gateway_resource.rpmrepo_gateway_proxy.id
  rest_api_id   = aws_api_gateway_rest_api.rpmrepo_gateway.id
}

resource "aws_api_gateway_integration" "rpmrepo_gateway_proxy" {
  http_method             = aws_api_gateway_method.rpmrepo_gateway_proxy.http_method
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_method.rpmrepo_gateway_proxy.resource_id
  rest_api_id             = aws_api_gateway_rest_api.rpmrepo_gateway.id
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.rpmrepo_gateway.invoke_arn
}

resource "aws_api_gateway_deployment" "rpmrepo_gateway" {
  depends_on = [
    aws_api_gateway_integration.rpmrepo_gateway_proxy,
  ]
  rest_api_id = aws_api_gateway_rest_api.rpmrepo_gateway.id
  stage_name  = "v1"
}

resource "aws_lambda_permission" "rpmrepo_gateway" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rpmrepo_gateway.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rpmrepo_gateway.execution_arn}/*/*"
  statement_id  = "AllowAPIGatewayInvoke"
}

##############################################################################
## Batch

# job policies

data "aws_iam_policy_document" "rpmrepo_batch_job_runtime" {
  statement {
    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:Put*",
    ]
    effect = "Allow"
    resources = [
      aws_s3_bucket.rpmrepo_s3.arn,
      "${aws_s3_bucket.rpmrepo_s3.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "rpmrepo_batch_job_runtime" {
  name   = "rpmrepo-batch-job-runtime"
  policy = data.aws_iam_policy_document.rpmrepo_batch_job_runtime.json
}

data "aws_iam_policy_document" "rpmrepo_batch_job_role" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rpmrepo_batch_job" {
  assume_role_policy = data.aws_iam_policy_document.rpmrepo_batch_job_role.json
  name               = "rpmrepo-batch-job"

  tags = merge(
    var.imagebuilder_tags,
    { Name = "RPMrepo Batch Job Role" },
  )
}

resource "aws_iam_role_policy_attachment" "rpmrepo_batch_job_runtime" {
  role       = aws_iam_role.rpmrepo_batch_job.name
  policy_arn = aws_iam_policy.rpmrepo_batch_job_runtime.arn
}

# EC2 compute policies

data "aws_iam_policy_document" "rpmrepo_batch_ec2" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rpmrepo_batch_ec2" {
  assume_role_policy = data.aws_iam_policy_document.rpmrepo_batch_ec2.json
  name               = "rpmrepo-batch-ec2"

  tags = merge(
    var.imagebuilder_tags,
    { Name = "RPMrepo Batch EC2 Role" },
  )
}

resource "aws_iam_role_policy_attachment" "rpmrepo_batch_ec2_service" {
  role       = aws_iam_role.rpmrepo_batch_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "rpmrepo_batch_ec2" {
  name = "rpmrepo-batch-ec2"
  role = aws_iam_role.rpmrepo_batch_ec2.name
}

# Batch manager policies

data "aws_iam_policy_document" "rpmrepo_batch_mgr" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["batch.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rpmrepo_batch_mgr" {
  assume_role_policy = data.aws_iam_policy_document.rpmrepo_batch_mgr.json
  name               = "rpmrepo-batch-mgr"

  tags = merge(
    var.imagebuilder_tags,
    { Name = "RPMrepo Batch Manager Role" },
  )
}

resource "aws_iam_role_policy_attachment" "rpmrepo_batch_mgr_service" {
  role       = aws_iam_role.rpmrepo_batch_mgr.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# Batch compute environment

resource "aws_launch_template" "rpmrepo_batch_ec2" {
  name                   = "rpmrepo-batch-ec2"
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_size           = 512
    }
  }

  tags = merge(
    var.imagebuilder_tags,
    { Name = "RPMrepo Batch EC2 Compute" },
  )
}

resource "aws_security_group" "rpmrepo_batch_ec2" {
  name = "rpmrepo-batch-ec2"

  description = "RPMrepo Batch EC2 Job Execution"
  vpc_id      = data.aws_vpc.internal_vpc.id

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
    var.imagebuilder_tags,
    { Name = "RPMrepo Batch EC2 Job Execution" },
  )
}

resource "aws_batch_compute_environment" "rpmrepo_batch" {
  compute_environment_name_prefix = "rpmrepo-batch"
  compute_resources {
    image_id      = "ami-0ec7896dee795dfa9"
    instance_role = aws_iam_instance_profile.rpmrepo_batch_ec2.arn
    instance_type = [
      "m5.large",
    ]
    launch_template {
      launch_template_name = aws_launch_template.rpmrepo_batch_ec2.name
      version              = "$Latest"
    }
    max_vcpus = 16
    min_vcpus = 0
    security_group_ids = [
      aws_security_group.rpmrepo_batch_ec2.id,
    ]
    subnets = data.aws_subnet_ids.internal_subnets.ids
    type    = "EC2"
  }
  depends_on   = [aws_iam_role_policy_attachment.rpmrepo_batch_mgr_service]
  service_role = aws_iam_role.rpmrepo_batch_mgr.arn
  type         = "MANAGED"

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [compute_resources[0].desired_vcpus]
  }

  tags = merge(
    var.imagebuilder_tags,
    { Name = "RPMrepo Batch Compute Environment" },
  )
}

resource "aws_batch_job_queue" "rpmrepo_batch" {
  name     = "rpmrepo-batch"
  priority = 1
  state    = "ENABLED"

  compute_environments = [aws_batch_compute_environment.rpmrepo_batch.arn]
  depends_on           = [aws_batch_compute_environment.rpmrepo_batch]

  tags = merge(
    var.imagebuilder_tags,
    { Name = "RPMrepo Batch Queue" },
  )
}
