# The product: an internal-only Container Apps environment in the workload subnet. No public
# ingress; it runs as the workload identity and reads secrets from Key Vault, never from env files.

resource "azurerm_container_app_environment" "this" {
  name                           = "${var.prefix}-env"
  location                       = azurerm_resource_group.this.location
  resource_group_name            = azurerm_resource_group.this.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  infrastructure_subnet_id       = azurerm_subnet.this["workload"].id
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = true
  tags                           = local.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_container_app" "product" {
  name                         = "${var.prefix}-app"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.workload.id]
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "product"
      image  = var.app_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.workload.client_id
      }
      env {
        name  = "KEY_VAULT_URI"
        value = azurerm_key_vault.this.vault_uri
      }
      env {
        name  = "DATA_CONTAINER_URL"
        value = "${azurerm_storage_account.data.primary_blob_endpoint}${azurerm_storage_container.app.name}"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 80
        path      = "/"
      }
    }
  }

  ingress {
    external_enabled = false
    target_port      = 80
    transport        = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  depends_on = [azurerm_role_assignment.workload_kv_secrets, azurerm_role_assignment.workload_blob]
}
