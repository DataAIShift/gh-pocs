variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}
 
variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}
 
variable "client_id" {
  description = "Azure Client ID (Managed Identity) for OIDC authentication"
  type        = string
}
 
variable "project" {
    type = string
    default = "daas"
}
variable "location" {
    type = string
    default = "West Europe"
}
 
variable "storage_account_name" {
  description = "Globally unique name for the Storage Account."
  type        = string
}
 
variable "container_name" {
  description = "Name of the Blob Container."
  type        = string
}
 