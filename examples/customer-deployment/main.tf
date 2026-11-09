# Example: deploying the product into "Contoso"'s Azure subscription with the TenantGuard baseline.
#
#   cp terraform.tfvars.example terraform.tfvars   # fill in the customer's values
#   terraform init && terraform plan
#
# Apply from a runner with private network access to the VNet (the Key Vault is private).

terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
  }
}

provider "azurerm" {
  subscription_id     = var.subscription_id
  storage_use_azuread = true # shared keys are disabled on every storage account

  features {
    key_vault {
      purge_soft_delete_on_destroy = false # never purge a customer's keys on destroy
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

module "baseline" {
  source = "../../modules/baseline"

  prefix                 = var.prefix
  location               = var.location
  allowed_locations      = var.allowed_locations
  security_contact_email = var.security_contact_email
  vendor_principal_id    = var.vendor_principal_id
  policy_enforcement     = var.policy_enforcement

  tags = {
    owner       = "platform-team@contoso.example"
    environment = "prod"
    customer    = "contoso"
  }
}
