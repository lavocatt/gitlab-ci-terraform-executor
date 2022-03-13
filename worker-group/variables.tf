variable "name" {
  description = "Name of the ASG."
  type        = string
}

variable "workspace_name" {
  description = "Used to distinguish between staging and stable."
  type        = string
}
variable "max_size" {
  description = "Max size of the group."
  type        = number
}
variable "min_size" {
  description = "Min size of the group."
  type        = number
}
variable "subnet_ids" {
  description = "List of subnets IDs in which the instances will be placed."
  type        = list(string)
}
variable "instance_types" {
  description = "List of instance types to be launched."
  type        = list(string)
}
variable "image_id" {
  description = "AMI ID to be launched."
  type        = string
}
variable "instance_profile_arn" {
  description = "ARN of instance profile to be attached the the instances."
  type        = string
}
variable "security_group_id" {
  description = "ID of a security group for the instances."
  type        = string
}
variable "composer_host" {
  description = "Host address of composer instance."
  type        = string
}
variable "offline_token_arn" {
  description = "ARN of offline_token secret."
  type        = string
}
variable "subscription_manager_command_arn" {
  description = "ARN of subscription command secret."
  type        = string
}
variable "cloudwatch_log_group" {
  description = "Cloudwatch log group that's used for logging."
  type        = string
}
