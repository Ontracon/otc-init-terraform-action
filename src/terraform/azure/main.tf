# Create a Resource Group for the Terraform State File
resource "azurerm_resource_group" "state-rg" {
  name     = var.resource_group_name
  location = var.cloud_region
  # lifecycle {
  #   prevent_destroy = true
  # }
  tags = merge(
    var.global_config, var.custom_tags,
    {
      Description = "Created by Terraform Bootstrap"
    }
  )
}
# Create a Storage Account for the Terraform State File
resource "azurerm_storage_account" "state-sta" {
  depends_on                = [azurerm_resource_group.state-rg]
  name                      = var.storage_account_name
  resource_group_name       = azurerm_resource_group.state-rg.name
  location                  = azurerm_resource_group.state-rg.location
  account_kind              = "StorageV2"
  account_tier              = "Standard"
  access_tier               = "Hot"
  account_replication_type  = "ZRS"
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }

  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = merge(
    var.global_config, var.custom_tags,
    {
      Description = "Created by Terraform Bootstrap"
    }
  )
}

# Create a Storage Container for the Core State File
resource "azurerm_storage_container" "core-container" {
  depends_on           = [azurerm_storage_account.state-sta]
  name                 = var.container_name
  storage_account_name = azurerm_storage_account.state-sta.name
}

# Create Delete Lock for Storage container
#resource "azurerm_management_lock" "core_container_lock" {
#  name       = "core-container-lock"
#  scope      = azurerm_storage_container.core-container.id
#  lock_level = "CanNotDelete"
#  notes      = "Locked to prevent accidental deletion."
#}
