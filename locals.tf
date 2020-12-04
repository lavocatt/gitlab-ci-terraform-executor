locals {
  workspace_name = var.TFC_WORKSPACE_NAME != "" ? trimprefix(var.TFC_WORKSPACE_NAME, "imagebuilder-") : terraform.workspace

  # Ensure that staging/stable composer get the same IP address every time.
  network_interface_ip_address_index = local.TFC_WORKSPACE_NAME == "staging" ? 11 : 10
}
