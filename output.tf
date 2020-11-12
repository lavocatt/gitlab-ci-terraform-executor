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

output "rhel_latest" {
  value = "${data.aws_ami.rhel8_x86.name} (${data.aws_ami.rhel8_x86.id})"
}
