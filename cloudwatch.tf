##############################################################################
## INTERNAL COMPOSER SYSLOG
# Create a log group that can contain multiple streams.
resource "aws_cloudwatch_log_group" "internal_composer" {
  name = "${local.workspace_name}_internal"

  tags = merge(
    var.imagebuilder_tags, { Name = "Internal composer log group for ${local.workspace_name}" },
  )
}

##############################################################################
## EXTERNAL COMPOSER SYSLOG
# Create a log group that can contain multiple streams.
resource "aws_cloudwatch_log_group" "external_composer" {
  name = "${local.workspace_name}_external"

  tags = merge(
    var.imagebuilder_tags, { Name = "External composer log group for ${local.workspace_name}" },
  )
}

##############################################################################
## AOC COMPOSER SYSLOG
# Create a log group that can contain multiple streams.
resource "aws_cloudwatch_log_group" "workers_aoc" {
  name = "${local.workspace_name}_workers_aoc"

  tags = merge(
    var.imagebuilder_tags, { Name = "Workers log group for AOC for ${local.workspace_name}" },
  )
}
