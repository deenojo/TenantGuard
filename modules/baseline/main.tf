# TenantGuard baseline: a product deployed into a customer's Azure subscription with nothing public,
# no shared secrets, every resource logged, and Azure Policy guardrails that keep it that way.

data "azurerm_client_config" "current" {}

locals {
  tags = merge(var.tags, { "managed-by" = "tenantguard" })

  subnets = {
    workload          = cidrsubnet(var.address_space, 23 - tonumber(split("/", var.address_space)[1]), 0)
    private-endpoints = cidrsubnet(var.address_space, 24 - tonumber(split("/", var.address_space)[1]), 2)
  }

  network_watcher_name = coalesce(var.network_watcher_name, "NetworkWatcher_${var.location}")
}

resource "azurerm_resource_group" "this" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_management_lock" "rg" {
  count      = var.enable_delete_lock ? 1 : 0
  name       = "${var.prefix}-cannot-delete"
  scope      = azurerm_resource_group.this.id
  lock_level = "CanNotDelete"
  notes      = "TenantGuard: protects the customer deployment from accidental deletion."
}
