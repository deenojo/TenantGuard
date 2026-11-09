# Logging: every resource sends its logs and metrics to one workspace, the subscription activity log
# is exported, and security-relevant changes page the security contact.

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.prefix}-logs"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

locals {
  # target => which diagnostic streams it supports
  diagnostic_targets = merge(
    {
      key-vault     = { id = azurerm_key_vault.this.id, logs = true, metrics = true }
      data-blob     = { id = "${azurerm_storage_account.data.id}/blobServices/default", logs = true, metrics = true }
      logs-blob     = { id = "${azurerm_storage_account.logs.id}/blobServices/default", logs = true, metrics = true }
      data-queue    = { id = "${azurerm_storage_account.data.id}/queueServices/default", logs = true, metrics = true }
      logs-queue    = { id = "${azurerm_storage_account.logs.id}/queueServices/default", logs = true, metrics = true }
      data-account  = { id = azurerm_storage_account.data.id, logs = false, metrics = true }
      vnet          = { id = azurerm_virtual_network.this.id, logs = true, metrics = true }
      container-env = { id = azurerm_container_app_environment.this.id, logs = true, metrics = true }
      nat-pip       = { id = azurerm_public_ip.nat.id, logs = true, metrics = true }
    },
    { for k, nsg in azurerm_network_security_group.this : "nsg-${k}" => { id = nsg.id, logs = true, metrics = false } }
  )
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each                   = local.diagnostic_targets
  name                       = "tenantguard-to-law"
  target_resource_id         = each.value.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = each.value.logs ? ["allLogs"] : []
    content {
      category_group = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = each.value.metrics ? ["AllMetrics"] : []
    content {
      category = metric.value
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  count                      = var.enable_activity_log_export ? 1 : 0
  name                       = "${var.prefix}-activity-to-law"
  target_resource_id         = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = ["Administrative", "Security", "Policy", "Alert", "ServiceHealth", "ResourceHealth"]
    content {
      category = enabled_log.value
    }
  }
}

resource "azurerm_monitor_action_group" "security" {
  name                = "${var.prefix}-security"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "tgsecurity"
  tags                = local.tags

  email_receiver {
    name                    = "security-contact"
    email_address           = var.security_contact_email
    use_common_alert_schema = true
  }
}

locals {
  # Changes that should never happen silently in a customer deployment.
  alert_operations = {
    policy-assignment-write = "Microsoft.Authorization/policyAssignments/write"
    policy-assignment-del   = "Microsoft.Authorization/policyAssignments/delete"
    role-assignment-write   = "Microsoft.Authorization/roleAssignments/write"
    nsg-write               = "Microsoft.Network/networkSecurityGroups/write"
    nsg-delete              = "Microsoft.Network/networkSecurityGroups/delete"
    nsg-rule-write          = "Microsoft.Network/networkSecurityGroups/securityRules/write"
    nsg-rule-delete         = "Microsoft.Network/networkSecurityGroups/securityRules/delete"
    key-vault-write         = "Microsoft.KeyVault/vaults/write"
    key-vault-delete        = "Microsoft.KeyVault/vaults/delete"
    public-ip-write         = "Microsoft.Network/publicIPAddresses/write"
  }
}

resource "azurerm_monitor_activity_log_alert" "security" {
  for_each            = local.alert_operations
  name                = "${var.prefix}-${each.key}"
  resource_group_name = azurerm_resource_group.this.name
  location            = "global"
  scopes              = [azurerm_resource_group.this.id]
  description         = "TenantGuard: ${each.value} in the customer deployment."
  tags                = local.tags

  criteria {
    category       = "Administrative"
    operation_name = each.value
  }

  action {
    action_group_id = azurerm_monitor_action_group.security.id
  }
}
