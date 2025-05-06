variable "location" {
  description = "The Azure location where the resources will be created."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group where the resources will be created."
  type        = string
}

variable "virtual_network_name" {
  description = "The name of the virtual network."
  type        = string
}
