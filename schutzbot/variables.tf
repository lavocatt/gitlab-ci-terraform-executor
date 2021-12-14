variable "imagebuilder_tags" {
  type        = map(any)
  description = "Required AWS tags for Image Builder"
  default = {
    ServiceOwner : "Image Builder"
    AppCode : "IMGB-001"
  }
}

variable "workspace_name" {
  type = string
}

variable "internal_vpc_id" {
  type = string
}

variable "external_vpc_id" {
  type = string
}
