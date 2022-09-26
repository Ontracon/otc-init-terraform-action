variable "cloud_region" {
  type        = string
  description = "Define the cloud region"
}

variable "global_config" {
  type = object({
    customer_prefix = string
    env             = string
    product_id      = string
    application     = string
    app_name        = string
    costcenter      = string
  })
}

variable "custom_tags" {
  type        = map(string)
  default     = null
  description = "Set custom tags for deployment."
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
  default     = ""
}

variable "storage_account_name" {
  description = "The name of the storage account."
  type        = string
  default     = ""
}

variable "container_name" {
  description = "The name of the container where the backend stored."
  type        = string
  default     = ""
}
