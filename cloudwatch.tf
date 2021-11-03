##############################################################################
## INTERNAL COMPOSER SYSLOG
# Create a log group that can contain multiple streams.
resource "aws_cloudwatch_log_group" "internal_composer" {
  name = "${local.workspace_name}_internal"

  tags = merge(
    var.imagebuilder_tags, { Name = "Internal composer log group for ${local.workspace_name}" },
  )
}

# Create syslog streams
resource "aws_cloudwatch_log_stream" "internal_composer_syslog" {
  name           = "composer_syslog"
  log_group_name = aws_cloudwatch_log_group.internal_composer.name
}

resource "aws_cloudwatch_log_stream" "internal_worker_syslog" {
  name           = "worker_syslog"
  log_group_name = aws_cloudwatch_log_group.internal_composer.name
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

# Create syslog streams
resource "aws_cloudwatch_log_stream" "external_composer_syslog" {
  name           = "composer_syslog"
  log_group_name = aws_cloudwatch_log_group.external_composer.name
}

resource "aws_cloudwatch_log_stream" "external_worker_syslog" {
  name           = "worker_syslog"
  log_group_name = aws_cloudwatch_log_group.external_composer.name
}

##############################################################################
## AOC COMPOSER SYSLOG
# Create a log group that can contain multiple streams.
resource "aws_cloudwatch_log_group" "workers_aoc" {
  name = "${local.workspace_name}_workers_aoc"

  tags = merge(
    var.imagebuilder_tags, { Name = "Workers log group for AOC (${local.workspace_name})" },
  )
}

resource "aws_cloudwatch_log_stream" "worker_aoc_syslog" {
  name           = "worker_syslog"
  log_group_name = aws_cloudwatch_log_group.workers_aoc.name
}
