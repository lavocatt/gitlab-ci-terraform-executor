locals {
  workspace_name = var.TFC_WORKSPACE_NAME != "" ? trimprefix(var.TFC_WORKSPACE_NAME, "imagebuilder-") : terraform.workspace
}
