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

# Use a template to inject the workflow variables into your script
data "template_file" "setup_script" {
  template = file("${path.module}/scripts/setup-runner.sh")
  vars = {
    repo_url     = var.github_repo_url
    token        = var.github_runner_token
    runner_name  = var.runner_name
    labels       = var.runner_labels
    admin_user   = var.admin_username
  }
}

resource "azurerm_linux_virtual_machine" "runner_vm" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = azurerm_resource_group.runner_rg.name
  network_interface_ids = [azurerm_network_interface.runner_nic.id]
  size                  = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true

  # Injecting the setup script via Cloud-Init
  # base64encode is mandatory for custom_data in Azure
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
    sku       = var.ubuntu_os_version # e.g., "22_04-lts-gen2"
    version   = "latest"
  }

  # --- CRITICAL MANAGEMENT BLOCK ---
  lifecycle {
    # 1. Ignore changes to custom_data so new GitHub tokens don't kill the VM
    ignore_changes = [
      custom_data,
    ]

    # 2. Strategy for "force_rebuild": Create the new VM before deleting the old one
    # This prevents downtime during tool upgrades (Blue-Green)
    create_before_destroy = true
  }

  tags = var.tags
}