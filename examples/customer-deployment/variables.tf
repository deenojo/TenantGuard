variable "subscription_id" {
  description = "The customer's subscription."
  type        = string
}

variable "prefix" {
  type    = string
  default = "contoso"
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "allowed_locations" {
  type    = list(string)
  default = ["eastus2", "centralus"]
}

variable "security_contact_email" {
  type = string
}

variable "vendor_principal_id" {
  type    = string
  default = null
}

variable "policy_enforcement" {
  description = "Start with false (audit) in a brownfield subscription, then switch to true."
  type        = bool
  default     = true
}
