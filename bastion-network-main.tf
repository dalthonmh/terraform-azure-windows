############################
## Network (catastro) - Main ##
############################

# Create a Resource Group
resource "azurerm_resource_group" "bastion-rg" {
  name     = "${var.bastion-windows-vm-hostname}-rg"
  location = var.location
  tags = {
    environment = var.environment
  }
}

# Create the VNET
resource "azurerm_virtual_network" "bastion-vnet" {
  name                = "${var.bastion-windows-vm-hostname}-vnet"
  address_space       = [var.bastion-vnet-cidr]
  resource_group_name = azurerm_resource_group.bastion-rg.name
  location            = azurerm_resource_group.bastion-rg.location
  tags = {
    environment = var.environment
  }
}

# Create a subnet for bastion
resource "azurerm_subnet" "bastion-subnet" {
  name                 = "${var.bastion-windows-vm-hostname}-subnet"
  address_prefixes     = [var.bastion-subnet-cidr]
  virtual_network_name = azurerm_virtual_network.bastion-vnet.name
  resource_group_name  = azurerm_resource_group.bastion-rg.name
}


