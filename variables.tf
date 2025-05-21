variable "subscription_id" {
  description = "The Azure subscription ID to use for the provider."
  type        = string
}

variable "dns_subscription_id" {
  type        = string
  description = "The subscription ID for the DNS provider"
}

variable "default_admin_group_object_id" {
  description = "The object ID of the Azure AD group to assign as AKS admin."
  type        = string
}

variable "enable_vpn" {
  description = "Enable VPN Gateway."
  type        = bool
  default     = false
}

variable "enabled_prod_aks" {
  description = "Create dev AKS cluster"
  type        = bool
  default     = false
}

variable "enabled_dev_aks" {
  description = "Create dev AKS cluster"
  type        = bool
  default     = false
}

variable "managed_subscription_ids" {
  description = "List of subscription IDs to manage"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    AutoPowerMgmt = "Enabled"
    Environment   = "Lab"
    Purpose       = "ArgoCD"
  }
}