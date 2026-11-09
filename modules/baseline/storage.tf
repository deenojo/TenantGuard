# Storage: private, Entra ID auth only (shared keys off), TLS 1.2, CMK + infrastructure encryption,
# soft delete and versioning. One account for app data, one for flow logs.

locals {
  storage_accounts = {
    data = "${var.prefix}data"
    logs = "${var.prefix}logs"
  }
}

resource "azurerm_storage_account" "data" {
  #checkov:skip=CKV_AZURE_33:Classic Storage Analytics queue logging needs shared-key access, which is disabled. Queue (and blob) logs go to Log Analytics via diagnostic settings in logging.tf.
  name                              = local.storage_accounts.data
  location                          = azurerm_resource_group.this.location
  resource_group_name               = azurerm_resource_group.this.name
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = "GZRS"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  public_network_access_enabled     = false
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true
  cross_tenant_replication_enabled  = false
  local_user_enabled                = false
  sftp_enabled                      = false
  tags                              = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage.id]
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage.versionless_id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  sas_policy {
    expiration_period = "00.01:00:00"
    expiration_action = "Log"
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  depends_on = [azurerm_role_assignment.storage_cmk]
}

resource "azurerm_storage_account" "logs" {
  #checkov:skip=CKV_AZURE_33:Classic Storage Analytics queue logging needs shared-key access, which is disabled. Queue (and blob) logs go to Log Analytics via diagnostic settings in logging.tf.
  name                              = local.storage_accounts.logs
  location                          = azurerm_resource_group.this.location
  resource_group_name               = azurerm_resource_group.this.name
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = "GZRS"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  public_network_access_enabled     = false
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true
  cross_tenant_replication_enabled  = false
  local_user_enabled                = false
  sftp_enabled                      = false
  tags                              = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage.id]
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage.versionless_id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 90
    }
    container_delete_retention_policy {
      days = 90
    }
  }

  sas_policy {
    expiration_period = "00.01:00:00"
    expiration_action = "Log"
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  depends_on = [azurerm_role_assignment.storage_cmk]
}

resource "azurerm_storage_container" "app" {
  #checkov:skip=CKV2_AZURE_21:Blob read/write/delete logs (StorageRead etc.) are sent by the blobServices diagnostic setting in logging.tf; Checkov only recognises the classic Storage Analytics form.
  name                  = "app-data"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "private"
}
