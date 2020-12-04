locals {
  # Set the workspace_name without the imagebuilder- prefix.
  workspace_name = var.TFC_WORKSPACE_NAME != "" ? trimprefix(var.TFC_WORKSPACE_NAME, "imagebuilder-") : terraform.workspace

  # Ensure that staging/stable composer get the same IP address every time.
  network_interface_ip_address_index = local.workspace_name == "staging" ? 11 : 10
}
