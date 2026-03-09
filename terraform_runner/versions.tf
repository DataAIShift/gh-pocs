terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }

    template = {
    source  = "hashicorp/template"
    version = "~> 2.2"
  }
}

  backend "azurerm" {
    # Backend configuration will be passed via CLI
    # This allows using OIDC authentication dynamically
  }
}