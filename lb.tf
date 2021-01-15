##############################################################################
## LOAD BALANCERS
# External composer.
resource "aws_eip" "external_composer_lb_elastic_ip" {
  vpc = true

  tags = merge(
    var.imagebuilder_tags, { Name = "External Composer EIP (${local.workspace_name})" },
  )
}

resource "aws_lb" "external_composer_lb" {
  # Only letters, numbers, and hyphens allowed in the name for these.
  name               = "external-composer-lb-${local.workspace_name}"
  load_balancer_type = "network"

  tags = merge(
    var.imagebuilder_tags, { Name = "External Composer LB ${local.workspace_name}" },
  )

  subnet_mapping {
    subnet_id     = data.aws_subnet.external_subnet_primary.id
    allocation_id = aws_eip.external_composer_lb_elastic_ip.id
  }
}

resource "aws_lb_listener" "external_composer" {
  load_balancer_arn = aws_lb.external_composer_lb.arn
  port              = "9876"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external_composer.arn
  }

  # No tags allowed for this resource.
}

resource "aws_lb_target_group" "external_composer" {
  # Only letters, numbers, and hyphens allowed in the name for these.
  # NOTE(mhayden): Random UUID here helps prevent dependency issues in AWs.
  # See https://stackoverflow.com/questions/57183814/error-deleting-target-group-resourceinuse-when-changing-target-ports-in-aws-thr
  name        = "external-composer-${substr(uuid(), 0, 3)}-${local.workspace_name}"
  port        = 443
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.external_vpc.id

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }

  tags = merge(
    var.imagebuilder_tags, { Name = "External Composer Target Group ${local.workspace_name}" },
  )
}

resource "aws_lb_target_group_attachment" "external_composer" {
  target_group_arn = aws_lb_target_group.external_composer.arn
  target_id        = aws_instance.composer_external.id
  port             = 443

  # No tags allowed for this resource.
}
