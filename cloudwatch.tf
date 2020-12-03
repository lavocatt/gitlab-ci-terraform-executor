##############################################################################
## INTERNAL COMPOSER SYSLOG
# Create a log group that can contain multiple streams.
resource "aws_cloudwatch_log_group" "internal_composer" {
  name = "internal_composer_${local.workspace_name}"

  tags = merge(
    var.imagebuilder_tags, { Name = "Internal composer log group for ${local.workspace_name}" },
  )
}

# Create a syslog stream.
resource "aws_cloudwatch_log_stream" "internal_composer_syslog" {
  name           = "internal_composer_syslog"
  log_group_name = aws_cloudwatch_log_group.internal_composer.name
}
