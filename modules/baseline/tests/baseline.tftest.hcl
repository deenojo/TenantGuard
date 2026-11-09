# Plan-and-apply against a MOCK azurerm provider: no Azure account, no cost. These tests assert the
# security properties of the baseline, so a change that weakens one fails CI.

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "11111111-1111-1111-1111-111111111111"
      object_id       = "22222222-2222-2222-2222-222222222222"
      subscription_id = "33333333-3333-3333-3333-333333333333"
    }
  }
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg"
    }
  }
  mock_resource "azurerm_virtual_network" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Network/virtualNetworks/contoso-vnet"
    }
  }
  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Network/virtualNetworks/contoso-vnet/subnets/workload"
    }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Network/networkSecurityGroups/contoso-nsg"
    }
  }
  mock_resource "azurerm_public_ip" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Network/publicIPAddresses/contoso-nat-pip"
    }
  }
  mock_resource "azurerm_nat_gateway" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Network/natGateways/contoso-nat"
    }
  }
  mock_resource "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id           = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.OperationalInsights/workspaces/contoso-logs"
      workspace_id = "55555555-5555-5555-5555-555555555555"
    }
  }
  mock_resource "azurerm_key_vault" {
    defaults = {
      id        = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.KeyVault/vaults/contoso-kv"
      vault_uri = "https://contoso-kv.vault.azure.net/"
    }
  }
  mock_resource "azurerm_key_vault_key" {
    defaults = {
      id             = "https://contoso-kv.vault.azure.net/keys/contoso-storage-cmk/0123456789abcdef0123456789abcdef"
      versionless_id = "https://contoso-kv.vault.azure.net/keys/contoso-storage-cmk"
    }
  }
  mock_resource "azurerm_storage_account" {
    defaults = {
      id                    = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Storage/storageAccounts/contosodata"
      primary_blob_endpoint = "https://contosodata.blob.core.windows.net/"
    }
  }
  mock_resource "azurerm_storage_container" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Storage/storageAccounts/contosodata/blobServices/default/containers/app-data"
    }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/contoso-id"
      principal_id = "66666666-6666-6666-6666-666666666666"
      client_id    = "77777777-7777-7777-7777-777777777777"
    }
  }
  mock_resource "azurerm_container_app_environment" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.App/managedEnvironments/contoso-env"
    }
  }
  mock_resource "azurerm_monitor_action_group" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Insights/actionGroups/contoso-security"
    }
  }
  mock_resource "azurerm_policy_definition" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/providers/Microsoft.Authorization/policyDefinitions/tg-contoso-policy"
    }
  }
  mock_resource "azurerm_resource_group_policy_assignment" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Authorization/policyAssignments/tg-policy"
    }
  }
  mock_resource "azurerm_role_definition" {
    defaults = {
      id                          = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Authorization/roleDefinitions/88888888-8888-8888-8888-888888888888"
      role_definition_resource_id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/contoso-rg/providers/Microsoft.Authorization/roleDefinitions/88888888-8888-8888-8888-888888888888"
    }
  }
  mock_data "azurerm_policy_set_definition" {
    defaults = {
      id = "/providers/Microsoft.Authorization/policySetDefinitions/cis-mock"
    }
  }
}

variables {
  prefix                 = "contoso"
  location               = "eastus2"
  allowed_locations      = ["eastus2", "centralus"]
  security_contact_email = "security@contoso.example"
  vendor_principal_id    = "44444444-4444-4444-4444-444444444444"
  tags                   = { owner = "platform@contoso.example", environment = "test" }
}

run "nothing_is_public" {
  command = apply

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == false && azurerm_key_vault.this.network_acls[0].default_action == "Deny"
    error_message = "Key Vault must not be reachable from public networks."
  }
  assert {
    condition = alltrue([for sa in [azurerm_storage_account.data, azurerm_storage_account.logs] :
    sa.public_network_access_enabled == false && sa.allow_nested_items_to_be_public == false && sa.network_rules[0].default_action == "Deny"])
    error_message = "Storage accounts must be private."
  }
  assert {
    condition     = azurerm_container_app.product.ingress[0].external_enabled == false && azurerm_container_app_environment.this.internal_load_balancer_enabled
    error_message = "The product must only be reachable inside the VNet."
  }
  assert {
    condition = alltrue([for nsg in azurerm_network_security_group.this :
    anytrue([for r in nsg.security_rule : r.access == "Deny" && r.direction == "Inbound" && r.source_address_prefix == "Internet"])])
    error_message = "Every subnet NSG must explicitly deny inbound internet traffic."
  }
  assert {
    condition     = length(azurerm_private_endpoint.this) == 3
    error_message = "Key Vault and both storage accounts must have private endpoints."
  }
}

run "no_shared_secrets_and_strong_crypto" {
  command = apply

  assert {
    condition = alltrue([for sa in [azurerm_storage_account.data, azurerm_storage_account.logs] :
      sa.shared_access_key_enabled == false && sa.min_tls_version == "TLS1_2" && sa.https_traffic_only_enabled &&
    sa.infrastructure_encryption_enabled && length(sa.customer_managed_key) == 1])
    error_message = "Storage must be keyless, TLS 1.2, double-encrypted and use the CMK."
  }
  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled && azurerm_key_vault.this.purge_protection_enabled
    error_message = "Key Vault must be RBAC-only and purge-protected."
  }
  assert {
    condition     = azurerm_key_vault_key.storage.key_type == "RSA-HSM" && length(azurerm_key_vault_key.storage.rotation_policy) == 1
    error_message = "The CMK must be HSM-backed with a rotation policy."
  }
}

run "least_privilege" {
  command = apply

  assert {
    condition     = !contains(azurerm_role_definition.vendor_operator.permissions[0].actions, "*")
    error_message = "The vendor role must not grant every action."
  }
  assert {
    condition = alltrue([for a in ["Microsoft.Authorization/*/write", "Microsoft.Authorization/*/delete", "Microsoft.Network/*/write", "Microsoft.Storage/storageAccounts/listKeys/action"] :
    contains(azurerm_role_definition.vendor_operator.permissions[0].not_actions, a)])
    error_message = "The vendor must not be able to change access, networking or read storage keys."
  }
  assert {
    condition     = length(azurerm_role_definition.vendor_operator.assignable_scopes) == 1 && one(azurerm_role_definition.vendor_operator.assignable_scopes) == azurerm_resource_group.this.id
    error_message = "The vendor role must be assignable only in this resource group."
  }
  assert {
    condition     = azurerm_role_assignment.workload_blob.scope == azurerm_storage_container.app.id
    error_message = "The workload identity gets blob access on its one container, not the account."
  }
}

run "everything_is_logged_and_alerted" {
  command = apply

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 11
    error_message = "Every resource (vault, blob/queue services, account, VNet, env, NAT IP, 2 NSGs) must send diagnostics."
  }
  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.activity_log) == 1
    error_message = "The subscription activity log must be exported."
  }
  assert {
    condition     = length(azurerm_monitor_activity_log_alert.security) == 10
    error_message = "Security-relevant changes (policy, roles, NSGs, vault, public IPs) must alert."
  }
  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days >= 90
    error_message = "Logs must be kept at least 90 days."
  }
}

run "policy_guardrails" {
  command = apply

  assert {
    condition     = length(azurerm_policy_definition.this) == 6 && length(azurerm_resource_group_policy_assignment.this) == 7
    error_message = "6 custom policies, 7 assignments (4 denies, allowed locations, 2 required tags)."
  }
  assert {
    condition     = alltrue([for a in azurerm_resource_group_policy_assignment.this : a.enforce])
    error_message = "Policies must be enforced by default."
  }
  assert {
    condition     = jsondecode(azurerm_policy_definition.this["deny-public-ip"].policy_rule).then.effect == "deny"
    error_message = "Public IPs must be denied."
  }
  assert {
    condition     = length(azurerm_resource_group_policy_assignment.cis) == 1
    error_message = "The CIS initiative must be assigned."
  }
  assert {
    condition     = azurerm_resource_policy_exemption.nat_ip.resource_id == azurerm_public_ip.nat.id
    error_message = "Only the NAT egress IP is exempt from the public-IP deny."
  }
}

run "audit_only_rollout" {
  command = plan
  variables {
    policy_enforcement  = false
    vendor_principal_id = null
  }

  assert {
    condition     = alltrue([for a in azurerm_resource_group_policy_assignment.this : !a.enforce])
    error_message = "policy_enforcement = false must switch every custom assignment to audit (DoNotEnforce)."
  }
  assert {
    condition     = length(azurerm_role_assignment.vendor_operator) == 0
    error_message = "No vendor principal, no vendor access."
  }
}

run "rejects_short_log_retention" {
  command = plan
  variables {
    log_retention_days = 30
  }
  expect_failures = [var.log_retention_days]
}

run "rejects_missing_owner_tag" {
  command = plan
  variables {
    tags = { environment = "test" }
  }
  expect_failures = [var.tags]
}

run "rejects_invalid_prefix" {
  command = plan
  variables {
    prefix = "Contoso-Prod"
  }
  expect_failures = [var.prefix]
}
