# 1. Resource Group
resource "azurerm_resource_group" "runner_rg" {
  name     = var.resource_group_name
  location = var.location
}

# 2. Networking Data Sources
data "azurerm_virtual_network" "existing" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

data "azurerm_subnet" "existing" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group
}

# 3. Network Interface (The missing piece)
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

# 4. Script Template Preparation
data "template_file" "setup_script" {
  template = file("${path.module}/scripts/setup-runner.sh")
  vars = {
    repo_url    = var.github_repo_url
    token       = var.github_runner_token
    runner_name = var.runner_name
    labels      = var.runner_labels
    admin_user  = var.admin_username
  }
}

# 5. Virtual Machine
resource "azurerm_linux_virtual_machine" "runner_vm" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = azurerm_resource_group.runner_rg.name
  network_interface_ids = [azurerm_network_interface.runner_nic.id]
  size                  = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true

  # Cloud-Init Script Injection
  custom_data = base64encode(data.template_file.setup_script.rendered)

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

  lifecycle {
    # Prevents reprovisioning when the GitHub token changes in the workflow
    ignore_changes = [
      custom_data,
    ]

    # Blue-Green: Create the new VM before deleting the old one
    create_before_destroy = false
  }

  tags = var.tags
}