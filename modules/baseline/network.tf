# Private networking: no public IPs anywhere (also denied by policy). The app is reachable only
# inside the VNet; PaaS services are reached through private endpoints.

resource "azurerm_virtual_network" "this" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each                          = local.subnets
  name                              = each.key
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [each.value]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = each.key == "private-endpoints" ? "Enabled" : "Disabled"
}

resource "azurerm_network_security_group" "this" {
  for_each            = local.subnets
  name                = "${var.prefix}-${each.key}-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  # Explicit, auditable deny for anything from the internet (Azure's default rule is lower priority).
  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = local.subnets
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# Private DNS so private endpoints resolve inside the VNet.
locals {
  private_dns_zones = {
    vault = "privatelink.vaultcore.azure.net"
    blob  = "privatelink.blob.core.windows.net"
  }
  private_endpoints = {
    kv        = { resource_id = azurerm_key_vault.this.id, subresource = "vault", zone = "vault" }
    data-blob = { resource_id = azurerm_storage_account.data.id, subresource = "blob", zone = "blob" }
    logs-blob = { resource_id = azurerm_storage_account.logs.id, subresource = "blob", zone = "blob" }
  }
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = local.private_dns_zones
  name                  = "${var.prefix}-${each.key}-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "this" {
  for_each            = local.private_endpoints
  name                = "${var.prefix}-${each.key}-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.this["private-endpoints"].id
  tags                = local.tags

  private_service_connection {
    name                           = "${var.prefix}-${each.key}"
    private_connection_resource_id = each.value.resource_id
    subresource_names              = [each.value.subresource]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.this[each.value.zone].id]
  }
}

# VNet flow logs: who talked to what, kept 90+ days and analyzed in the workspace.
resource "azurerm_network_watcher_flow_log" "vnet" {
  count                = var.enable_flow_logs ? 1 : 0
  name                 = "${var.prefix}-vnet-flowlog"
  network_watcher_name = local.network_watcher_name
  resource_group_name  = var.network_watcher_resource_group
  target_resource_id   = azurerm_virtual_network.this.id
  storage_account_id   = azurerm_storage_account.logs.id
  enabled              = true
  version              = 2
  tags                 = local.tags

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.this.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.this.location
    workspace_resource_id = azurerm_log_analytics_workspace.this.id
    interval_in_minutes   = 10
  }
}

# Egress: Azure is retiring implicit "default outbound access", so the workload subnet gets a NAT
# gateway. Its public IP is the ONLY public IP allowed in the deployment: it is created before the
# deny-public-IP policy is assigned and carries an explicit, auditable policy exemption (policy.tf).
resource "azurerm_public_ip" "nat" {
  name                = "${var.prefix}-nat-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "this" {
  name                    = "${var.prefix}-nat"
  location                = azurerm_resource_group.this.location
  resource_group_name     = azurerm_resource_group.this.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
  tags                    = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "workload" {
  subnet_id      = azurerm_subnet.this["workload"].id
  nat_gateway_id = azurerm_nat_gateway.this.id
}
