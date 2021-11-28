locals {
  # Set the workspace_name without the imagebuilder- prefix.
  workspace_name = var.TFC_WORKSPACE_NAME != "" ? trimprefix(var.TFC_WORKSPACE_NAME, "imagebuilder-") : terraform.workspace

  spot_fleet_worker_aoc_count = 16
}
