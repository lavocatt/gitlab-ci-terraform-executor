##############################################################################
## GLOBAL VARIABLES

# The default tags for all resources created by Terraform.
variable "imagebuilder_tags" {
  type        = map(any)
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

variable "composer_commit" {
  type        = string
  description = "The Git SHA of osbuild-composer to deploy on both the composer and worker nodes."
}

variable "osbuild_commit" {
  type        = string
  description = "The Git SHA of osbuild to deploy on the worker nodes."
}

variable "composer_host_internal" {
  type        = string
  description = "Hostname of the composer instance on the internal network."
}

variable "composer_host_internal_staging" {
  type        = string
  description = "Hostname of the staging composer instance on the internal network."
}

variable "composer_host_external" {
  type        = string
  description = "Hostname of the composer instance on the internal network."
}

variable "composer_host_external_staging" {
  type        = string
  description = "Hostname of the staging composer instance on the internal network."
}

variable "composer_host_aoc" {
  type        = string
  description = "Hostname of composer behind api.openshift.com."
}

variable "composer_host_aoc_staging" {
  type        = string
  description = "Hostname of composer behind api.stage.openshift.com."
}

variable "TFC_WORKSPACE_NAME" {
  type    = string
  default = ""
}
