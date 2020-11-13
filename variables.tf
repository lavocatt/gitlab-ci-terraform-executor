variable "imagebuilder_tags" {
  type        = map
  description = "Required AWS tags for Image Builder"
  default = {
    Name : "Image Builder Terraform State Storage"
    ServiceOwner : "Image Builder"
    AppCode : "IMGB-001"
  }
}

variable "state_bucket" {
  type        = string
  description = "S3 bucket that holds Terraform's state files"
  default     = "imagebuilder-terraform-state"
}
