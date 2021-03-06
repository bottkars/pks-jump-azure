variable "env_id" {}

variable "location" {}

variable "resource_group_name" {
  type = "string"
}

variable "network_name" {}

variable "resource_group_cidr" {}

locals {
  pks_cidr          = "${cidrsubnet(var.resource_group_cidr, 6, 3)}"
  pks_services_cidr = "${cidrsubnet(var.resource_group_cidr, 6, 4)}"
  k8s_services_cidr = "${cidrsubnet(var.resource_group_cidr, 8, 0)}"
}