# Variables to print after the `terraform apply` output.

output "availability_zones" {
  value = join(", ", data.aws_availability_zones.available.names)
}

output "internal_vpc" {
  value = "${data.aws_vpc.internal_vpc.tags.Name} (${data.aws_vpc.internal_vpc.id})"
}

output "internal_subnets" {
  value = join(", ", data.aws_subnet_ids.internal_subnets.ids)
}

output "external_vpc" {
  value = "${data.aws_vpc.external_vpc.tags.Name} (${data.aws_vpc.external_vpc.id})"
}

output "external_subnets" {
  value = join(", ", data.aws_subnet_ids.external_subnets.ids)
}

output "rhel8_x86" {
  value = "${data.aws_ami.rhel8_x86.name} (${data.aws_ami.rhel8_x86.id})"
}

output "workspace_name" {
  value = local.workspace_name
}
