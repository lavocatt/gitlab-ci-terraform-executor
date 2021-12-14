module "gitlab-runner" {
  source          = "./schutzbot"
  workspace_name  = local.workspace_name
  internal_vpc_id = data.aws_vpc.internal_vpc.id
  external_vpc_id = data.aws_vpc.external_vpc.id
}
