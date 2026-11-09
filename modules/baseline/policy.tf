# Azure Policy guardrails: the baseline can't drift. Custom deny policies (written here, so they're
# reviewable and testable) plus the built-in CIS Azure Foundations initiative in audit mode.

locals {
  enforcement = var.policy_enforcement

  custom_policies = {
    deny-public-ip = {
      display_name = "TenantGuard: deny public IP addresses"
      description  = "No public IPs in the customer deployment. The NAT gateway's egress IP is the only, exempted, exception."
      mode         = "All"
      rule = {
        "if"   = { "field" = "type", "equals" = "Microsoft.Network/publicIPAddresses" }
        "then" = { "effect" = "deny" }
      }
    }
    deny-internet-inbound-nsg-rules = {
      display_name = "TenantGuard: deny NSG rules that allow inbound traffic from the internet"
      description  = "Blocks any Allow/Inbound rule whose source is *, Internet or 0.0.0.0/0, standalone or inside an NSG."
      mode         = "All"
      rule = {
        "if" = {
          "anyOf" = [
            {
              "allOf" = [
                { "field" = "type", "equals" = "Microsoft.Network/networkSecurityGroups/securityRules" },
                { "field" = "Microsoft.Network/networkSecurityGroups/securityRules/access", "equals" = "Allow" },
                { "field" = "Microsoft.Network/networkSecurityGroups/securityRules/direction", "equals" = "Inbound" },
                { "field" = "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix", "in" = ["*", "Internet", "0.0.0.0/0"] },
              ]
            },
            {
              "allOf" = [
                { "field" = "type", "equals" = "Microsoft.Network/networkSecurityGroups" },
                {
                  "count" = {
                    "field" = "Microsoft.Network/networkSecurityGroups/securityRules[*]"
                    "where" = {
                      "allOf" = [
                        { "field" = "Microsoft.Network/networkSecurityGroups/securityRules[*].access", "equals" = "Allow" },
                        { "field" = "Microsoft.Network/networkSecurityGroups/securityRules[*].direction", "equals" = "Inbound" },
                        { "field" = "Microsoft.Network/networkSecurityGroups/securityRules[*].sourceAddressPrefix", "in" = ["*", "Internet", "0.0.0.0/0"] },
                      ]
                    }
                  }
                  "greater" = 0
                },
              ]
            },
          ]
        }
        "then" = { "effect" = "deny" }
      }
    }
    deny-public-storage = {
      display_name = "TenantGuard: storage accounts must be private, keyless and TLS 1.2"
      description  = "Denies storage accounts with public network access, shared keys, public blobs, HTTP or TLS below 1.2."
      mode         = "Indexed"
      rule = {
        "if" = {
          "allOf" = [
            { "field" = "type", "equals" = "Microsoft.Storage/storageAccounts" },
            {
              "anyOf" = [
                { "field" = "Microsoft.Storage/storageAccounts/publicNetworkAccess", "notEquals" = "Disabled" },
                { "field" = "Microsoft.Storage/storageAccounts/allowSharedKeyAccess", "notEquals" = false },
                { "field" = "Microsoft.Storage/storageAccounts/allowBlobPublicAccess", "notEquals" = false },
                { "field" = "Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly", "notEquals" = true },
                { "field" = "Microsoft.Storage/storageAccounts/minimumTlsVersion", "notEquals" = "TLS1_2" },
              ]
            },
          ]
        }
        "then" = { "effect" = "deny" }
      }
    }
    deny-weak-key-vault = {
      display_name = "TenantGuard: key vaults must be private, RBAC-only and purge-protected"
      description  = "Denies key vaults without purge protection, with access policies instead of RBAC, or reachable from public networks."
      mode         = "Indexed"
      rule = {
        "if" = {
          "allOf" = [
            { "field" = "type", "equals" = "Microsoft.KeyVault/vaults" },
            {
              "anyOf" = [
                { "field" = "Microsoft.KeyVault/vaults/enablePurgeProtection", "notEquals" = true },
                { "field" = "Microsoft.KeyVault/vaults/enableRbacAuthorization", "notEquals" = true },
                { "field" = "Microsoft.KeyVault/vaults/networkAcls.defaultAction", "notEquals" = "Deny" },
              ]
            },
          ]
        }
        "then" = { "effect" = "deny" }
      }
    }
    allowed-locations = {
      display_name = "TenantGuard: allowed locations"
      description  = "Resources may only be created in the regions the customer approved."
      mode         = "Indexed"
      parameters = {
        allowedLocations = { type = "Array", metadata = { displayName = "Allowed locations", strongType = "location" } }
      }
      rule = {
        "if" = {
          "allOf" = [
            { "field" = "location", "notIn" = "[parameters('allowedLocations')]" },
            { "field" = "location", "notEquals" = "global" },
          ]
        }
        "then" = { "effect" = "deny" }
      }
    }
    require-tag = {
      display_name = "TenantGuard: require a tag on resources"
      description  = "Denies resources missing the given tag."
      mode         = "Indexed"
      parameters = {
        tagName = { type = "String", metadata = { displayName = "Tag name" } }
      }
      rule = {
        "if"   = { "field" = "[concat('tags[', parameters('tagName'), ']')]", "exists" = "false" }
        "then" = { "effect" = "deny" }
      }
    }
  }

  assignments = merge(
    { for k in ["deny-public-ip", "deny-internet-inbound-nsg-rules", "deny-public-storage", "deny-weak-key-vault"] :
    k => { policy = k, parameters = {} } },
    { allowed-locations = { policy = "allowed-locations", parameters = { allowedLocations = { value = var.allowed_locations } } } },
    { for t in var.required_tags : "require-tag-${t}" => { policy = "require-tag", parameters = { tagName = { value = t } } } },
  )
}

resource "azurerm_policy_definition" "this" {
  for_each     = local.custom_policies
  name         = "tg-${var.prefix}-${each.key}"
  policy_type  = "Custom"
  mode         = each.value.mode
  display_name = each.value.display_name
  description  = each.value.description
  policy_rule  = jsonencode(each.value.rule)
  parameters   = try(jsonencode(each.value.parameters), null)
  metadata     = jsonencode({ category = "TenantGuard", version = "1.0.0" })
}

resource "azurerm_resource_group_policy_assignment" "this" {
  for_each             = local.assignments
  name                 = "tg-${each.key}"
  resource_group_id    = azurerm_resource_group.this.id
  policy_definition_id = azurerm_policy_definition.this[each.value.policy].id
  display_name         = "${azurerm_policy_definition.this[each.value.policy].display_name}${length(each.value.parameters) > 0 ? " (${join(", ", flatten([for p in values(each.value.parameters) : p.value]))})" : ""}"
  enforce              = local.enforcement
  parameters           = length(each.value.parameters) > 0 ? jsonencode(each.value.parameters) : null

  non_compliance_message {
    content = "Blocked by the TenantGuard baseline: ${azurerm_policy_definition.this[each.value.policy].description}"
  }

  # The NAT egress IP must exist before deny-public-ip is assigned; it is then exempted below.
  depends_on = [azurerm_public_ip.nat]
}

resource "azurerm_resource_policy_exemption" "nat_ip" {
  name                 = "tg-nat-egress-ip"
  resource_id          = azurerm_public_ip.nat.id
  policy_assignment_id = azurerm_resource_group_policy_assignment.this["deny-public-ip"].id
  exemption_category   = "Mitigated"
  display_name         = "NAT gateway egress IP (outbound only)"
  description          = "Outbound-only egress for the workload subnet. No inbound path: NSGs deny internet inbound and nothing listens on this IP."
}

data "azurerm_policy_set_definition" "cis" {
  count        = var.enable_cis_initiative ? 1 : 0
  display_name = var.cis_initiative_display_name
}

resource "azurerm_resource_group_policy_assignment" "cis" {
  count                = var.enable_cis_initiative ? 1 : 0
  name                 = "tg-cis-azure-foundations"
  resource_group_id    = azurerm_resource_group.this.id
  policy_definition_id = data.azurerm_policy_set_definition.cis[0].id
  display_name         = "${var.cis_initiative_display_name} (audit)"
  location             = azurerm_resource_group.this.location
  enforce              = true # the initiative's own effects are audit / auditIfNotExists

  identity {
    type = "SystemAssigned"
  }
}
