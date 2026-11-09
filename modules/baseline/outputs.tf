output "resource_group_id" { value = azurerm_resource_group.this.id }
output "vnet_id" { value = azurerm_virtual_network.this.id }
output "key_vault_uri" { value = azurerm_key_vault.this.vault_uri }
output "data_storage_account_id" { value = azurerm_storage_account.data.id }
output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.this.id }
output "workload_identity_client_id" { value = azurerm_user_assigned_identity.workload.client_id }
output "app_internal_fqdn" { value = azurerm_container_app.product.ingress[0].fqdn }
output "vendor_operator_role_id" { value = azurerm_role_definition.vendor_operator.role_definition_resource_id }
output "policy_assignment_ids" {
  value = merge(
    { for k, a in azurerm_resource_group_policy_assignment.this : k => a.id },
    var.enable_cis_initiative ? { cis = azurerm_resource_group_policy_assignment.cis[0].id } : {}
  )
}
