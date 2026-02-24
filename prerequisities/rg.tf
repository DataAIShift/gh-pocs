resource "azurerm_resource_group" "prereqs_rg" {
  name     = "pratik-prerequisites-rg"
  location = var.location
}