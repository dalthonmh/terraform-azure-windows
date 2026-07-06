####################################
## Windows VM (catastro) - Variables ##
####################################

# Windows bastion VM Admin User
variable "bastion-windows-admin-username" {
  type        = string
  description = "Windows bastion VM Admin User"
  default     = "azureuser"
}

# Windows bastion VM Admin Password
variable "bastion-windows-admin-password" {
  type        = string
  description = "Windows bastion VM Admin Password"
  default     = "AzureUserP@ss2026!"
  sensitive   = true
}

# Windows Bastion VM Hostname (limited to 15 characters long)
variable "bastion-windows-vm-hostname" {
  type        = string
  description = "Windows Bastion VM Hostname"
  default     = "catastro"
}

# Windows bastion VM Virtual Machine Size
variable "bastion-windows-vm-size" {
  type        = string
  description = "Windows bastion VM Size"
  default     = "Standard_B4ms"
}

##############
## OS Image ##
##############

# Windows Server 2022 Datacenter Azure Edition SKU (x64 Gen2)
variable "windows-2022-azure-edition-sku" {
  type        = string
  description = "Windows Server 2022 Datacenter: Azure Edition SKU used to build VMs"
  default     = "2022-datacenter-azure-edition"
}

# Windows Server 2019 SKU used to build VMs (kept for reference)
variable "windows-2019-sku" {
  type        = string
  description = "Windows Server 2019 SKU used to build VMs"
  default     = "2019-Datacenter"
}

# Windows Server 2016 SKU used to build VMs
variable "windows-2016-sku" {
  type        = string
  description = "Windows Server 2016 SKU used to build VMs"
  default     = "2016-Datacenter"
}

# Windows Server 2012 R2 SKU used to build VMs
variable "windows-2012-sku" {
  type        = string
  description = "Windows Server 2012 R2 SKU used to build VMs"
  default     = "2012-R2-Datacenter"
}