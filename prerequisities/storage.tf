resource "azurerm_storage_account" "prereqs_sa" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.prereqs_rg.name
  location                 = azurerm_resource_group.prereqs_rg.location
  account_tier             = "Standard"
  account_replication_type = "RAGRS"
  account_kind             = "StorageV2"
  public_network_access_enabled = true
  min_tls_version = "TLS1_2"
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
  tags = {
    ManagedBy = "Terraform"
  }
}
 
# Blob Container equivalent (publicAccess: 'None')
resource "azurerm_storage_container" "container" {
  name                  = var.container_name
  storage_account_id = azurerm_storage_account.prereqs_sa.id
  container_access_type = "private"
}
 