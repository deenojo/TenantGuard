variable "prefix" {
  description = "Short, lowercase name for this customer deployment. Used in every resource name."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.prefix))
    error_message = "prefix must be 3-12 lowercase letters/digits, starting with a letter (storage and Key Vault naming rules)."
  }
}

variable "location" {
  description = "Azure region for every resource."
  type        = string
}

variable "allowed_locations" {
  description = "Regions resources may be created in (enforced by Azure Policy). Must include location."
  type        = list(string)
  validation {
    condition     = length(var.allowed_locations) > 0
    error_message = "allowed_locations must list at least one region."
  }
}

variable "tags" {
  description = "Tags for every resource. owner and environment are required (and enforced by Azure Policy)."
  type        = map(string)
  validation {
    condition     = contains(keys(var.tags), "owner") && contains(keys(var.tags), "environment")
    error_message = "tags must include owner and environment."
  }
}

variable "required_tags" {
  description = "Tag names Azure Policy requires on every resource in the deployment."
  type        = list(string)
  default     = ["owner", "environment"]
}

variable "address_space" {
  description = "VNet address space. Subnets are carved from it: /23 for workloads, /24 for private endpoints."
  type        = string
  default     = "10.40.0.0/16"
  validation {
    condition     = can(cidrhost(var.address_space, 0)) && tonumber(split("/", var.address_space)[1]) <= 22
    error_message = "address_space must be a valid CIDR of /22 or larger."
  }
}

variable "log_retention_days" {
  description = "Log Analytics retention. 90 days minimum."
  type        = number
  default     = 365
  validation {
    condition     = var.log_retention_days >= 90 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 90 and 730."
  }
}

variable "security_contact_email" {
  description = "Receives activity-log security alerts (policy, NSG, Key Vault and role changes)."
  type        = string
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.security_contact_email))
    error_message = "security_contact_email must be an email address."
  }
}

variable "vendor_principal_id" {
  description = "Object ID of the vendor's operator group in the customer's tenant. Gets the narrow Vendor Operator role on this resource group only. null = no vendor access."
  type        = string
  default     = null
}

variable "app_image" {
  description = "Container image for the product."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "policy_enforcement" {
  description = "true = deny non-compliant resources. false = audit only (DoNotEnforce), for a staged rollout in a customer tenant."
  type        = bool
  default     = true
}

variable "enable_cis_initiative" {
  description = "Assign the built-in CIS Microsoft Azure Foundations Benchmark initiative (audit) to the resource group."
  type        = bool
  default     = true
}

variable "cis_initiative_display_name" {
  description = "Display name of the built-in CIS initiative in the customer's tenant."
  type        = string
  default     = "CIS Microsoft Azure Foundations Benchmark v2.0.0"
}

variable "enable_activity_log_export" {
  description = "Export the subscription activity log to the workspace. Disable if the customer already centralizes it."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "VNet flow logs via the region's Network Watcher (Azure creates one per region automatically)."
  type        = bool
  default     = true
}

variable "network_watcher_name" {
  description = "Network Watcher name. Defaults to Azure's auto-created NetworkWatcher_<location>."
  type        = string
  default     = null
}

variable "network_watcher_resource_group" {
  description = "Resource group of the Network Watcher."
  type        = string
  default     = "NetworkWatcherRG"
}

variable "enable_delete_lock" {
  description = "CanNotDelete lock on the resource group. Remove it deliberately before a teardown."
  type        = bool
  default     = true
}
