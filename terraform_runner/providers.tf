provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  
  # Add this line to bypass the registration error
  skip_provider_registration = true
  
  # OIDC authentication will be used via environment variables
  use_oidc = true
}