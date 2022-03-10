locals {
  # Set the workspace_name without the imagebuilder- prefix.
  workspace_name = var.TFC_WORKSPACE_NAME != "" ? trimprefix(var.TFC_WORKSPACE_NAME, "imagebuilder-") : terraform.workspace

  spot_fleet_worker_aoc_count    = local.workspace_name == "staging" ? 0 : 16
  spot_fleet_worker_fedora_count = 1
}
