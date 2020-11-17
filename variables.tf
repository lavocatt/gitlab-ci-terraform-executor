##############################################################################
## GLOBAL VARIABLES

# The default tags for all resources created by Terraform.
variable "imagebuilder_tags" {
  type        = map
  description = "Required AWS tags for Image Builder"
  default = {
    ServiceOwner : "Image Builder"
    AppCode : "IMGB-001"
  }
}

# These instance types are used with the spot fleet to determine what type of
# instances should be used for running workers.
variable "worker_instance_types" {
  description = "Instance types for workers"
  default = [
    "c5.large",
    "c5d.large",
    "c5a.large",
    "c5.xlarge",
    "c5d.xlarge",
    "c5a.xlarge"
  ]
}
