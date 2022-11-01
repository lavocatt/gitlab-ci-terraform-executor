output "autoscaling_group_arn" {
  value       = aws_autoscaling_group.workers.arn
  description = "The private IP address of the main server instance."
}
