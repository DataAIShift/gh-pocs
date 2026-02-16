resource "azurerm_resource_group" "runner_rg" {
  name     = var.resource_group_name
  location = var.location
}


# Data source for existing VNet
data "azurerm_virtual_network" "existing" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

# Data source for existing Subnet
data "azurerm_subnet" "existing" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group
}


# Public IP for NAT Gateway (allows outbound internet access)
# resource "azurerm_public_ip" "nat_gateway" {
#   name                = "${var.vm_name}-nat-pip"
#   location            = var.location
#   resource_group_name = data.azurerm_resource_group.existing.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
#   zones               = ["1"]

#   tags = var.tags
# }

# NAT Gateway for secure outbound internet access
# resource "azurerm_nat_gateway" "runner" {
#   name                = "${var.vm_name}-nat-gateway"
#   location            = var.location
#   resource_group_name = data.azurerm_resource_group.existing.name
#   sku_name            = "Standard"
#   zones               = ["1"]

#   tags = var.tags
# }

# # Associate Public IP with NAT Gateway
# resource "azurerm_nat_gateway_public_ip_association" "runner" {
#   nat_gateway_id       = azurerm_nat_gateway.runner.id
#   public_ip_address_id = azurerm_public_ip.nat_gateway.id
# }

# # Associate NAT Gateway with Subnet
# resource "azurerm_subnet_nat_gateway_association" "runner" {
#   subnet_id      = data.azurerm_subnet.existing.id
#   nat_gateway_id = azurerm_nat_gateway.runner.id
# }

# Network Interface (Private IP only - no public IP for security)
# Note: NSG creation removed due to Azure Policy restrictions on Any-to-Any rules
# The subnet should already have appropriate NSG rules configured
resource "azurerm_network_interface" "runner_nic" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.runner_rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.existing.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "runner_vm" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = azurerm_resource_group.runner_rg.name
  network_interface_ids = [azurerm_network_interface.runner_nic.id]
  size                  = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = var.ubuntu_os_version
    version   = "latest"
  }

  tags = var.tags
}

# Custom Script Extension to install GitHub Runner
# Note: Using inline commandToExecute because repository is internal (can't download from raw.githubusercontent.com)
resource "azurerm_virtual_machine_extension" "runner_setup" {
  name                 = "installGitHubRunner"
  virtual_machine_id   = azurerm_linux_virtual_machine.runner_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = jsonencode({
    commandToExecute = <<-EOT
      cat > /tmp/setup-runner.sh << 'SCRIPT_EOF'
${file("${path.module}/scripts/setup-runner.sh")}
SCRIPT_EOF
      chmod +x /tmp/setup-runner.sh
      /tmp/setup-runner.sh '${var.github_repo_url}' '${var.github_runner_token}' '${var.runner_name}' '${var.runner_labels}' '${var.admin_username}'
    EOT
  })

  tags = var.tags

  depends_on = [azurerm_linux_virtual_machine.runner_vm]
}