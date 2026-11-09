# Identity: managed identities only, no keys or passwords. Every role is scoped to the narrowest
# resource that works (a single container or vault, never the subscription).

resource "azurerm_user_assigned_identity" "workload" {
  name                = "${var.prefix}-workload-id"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

# Used by the storage accounts to unwrap their customer-managed key.
resource "azurerm_user_assigned_identity" "storage" {
  name                = "${var.prefix}-storage-id"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "workload_kv_secrets" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "workload_blob" {
  scope                = azurerm_storage_container.app.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "storage_cmk" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.storage.principal_id
  principal_type       = "ServicePrincipal"
}

# The deploying principal needs to create the CMK. Data-plane access works only from inside the
# VNet (the vault is private), so apply from a runner with private network access.
resource "azurerm_role_assignment" "deployer_kv_crypto" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Vendor access: operate the product, never change who has access or weaken security.
resource "azurerm_role_definition" "vendor_operator" {
  name        = "${var.prefix}-vendor-operator"
  scope       = azurerm_resource_group.this.id
  description = "TenantGuard: lets the vendor read, restart and roll out the product in this resource group only."

  permissions {
    actions = [
      "*/read",
      "Microsoft.App/containerApps/write",
      "Microsoft.App/containerApps/revisions/restart/action",
      "Microsoft.App/containerApps/revisions/activate/action",
      "Microsoft.App/containerApps/revisions/deactivate/action",
      "Microsoft.OperationalInsights/workspaces/query/read",
      "Microsoft.Insights/alertRules/read",
    ]
    not_actions = [
      "Microsoft.Authorization/*/write",
      "Microsoft.Authorization/*/delete",
      "Microsoft.Network/*/write",
      "Microsoft.Network/*/delete",
      "Microsoft.KeyVault/vaults/write",
      "Microsoft.Storage/storageAccounts/write",
      "Microsoft.Storage/storageAccounts/listKeys/action",
    ]
    data_actions     = []
    not_data_actions = []
  }

  assignable_scopes = [azurerm_resource_group.this.id]
}

resource "azurerm_role_assignment" "vendor_operator" {
  count              = var.vendor_principal_id == null ? 0 : 1
  scope              = azurerm_resource_group.this.id
  role_definition_id = azurerm_role_definition.vendor_operator.role_definition_resource_id
  principal_id       = var.vendor_principal_id
  principal_type     = "Group"
  description        = "Vendor operator group (TenantGuard)."
}
