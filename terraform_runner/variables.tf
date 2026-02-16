variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "location" {
  type        = string
  description = "The Azure region where resources will be created"
}

# --- VM Configuration ---

variable "vm_name" {
  type        = string
  description = "The name of the Virtual Machine"
}

variable "vm_size" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "The size of the Azure Virtual Machine"
}

variable "admin_username" {
  type        = string
  description = "Admin username for the VM"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
  sensitive   = true
}

variable "ubuntu_os_version" {
  type        = string
  default     = "22_04-lts-gen2"
  description = "The Ubuntu OS version to use"
}

# --- Networking ---

variable "vnet_name" {
  type        = string
  description = "The name of the Virtual Network"
}

variable "subnet_name" {
  type        = string
  description = "The name of the Subnet"
}

variable "vnet_resource_group" {
  type        = string
  description = "The resource group where the VNet is located"
}

# --- GitHub Runner Configuration ---

variable "github_runner_token" {
  type        = string
  description = "Registration token for the GitHub runner"
  sensitive   = true
}

variable "github_repo_url" {
  type        = string
  description = "The full URL of the GitHub repository"
}

variable "runner_name" {
  type        = string
  description = "Name of the self-hosted runner"
}

variable "runner_labels" {
  type        = string
  description = "Comma-separated labels for the runner"
}

# --- Metadata ---

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource"
  default     = {}
}