# Key Vault: RBAC only (no access policies), private, purge-protected, HSM-backed CMK with rotation.

resource "azurerm_key_vault" "this" {
  name                          = "${var.prefix}-kv"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "premium"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false
  tags                          = local.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_key_vault_key" "storage" {
  name         = "${var.prefix}-storage-cmk"
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA-HSM"
  key_size     = 3072
  key_opts     = ["wrapKey", "unwrapKey"]

  expiration_date = timeadd(timestamp(), "17520h") # 2 years; rotation below renews well before

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P730D"
    notify_before_expiry = "P29D"
  }

  lifecycle {
    ignore_changes = [expiration_date]
  }

  depends_on = [azurerm_role_assignment.deployer_kv_crypto]
}
