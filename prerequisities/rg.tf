resource "azurerm_resource_group" "prereqs_rg" {
  name     = "${var.project}-prerequisites-rg"
  location = var.location
}