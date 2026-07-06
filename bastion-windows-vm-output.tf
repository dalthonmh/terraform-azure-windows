#################################
## Windows VM (catastro) - Output ##
#################################

# Windows VM ID
output "bastion_windows_vm_id" {
  value = azurerm_windows_virtual_machine.bastion-windows-vm.id
}

# Windows VM Name (should be 'catastro')
output "bastion_windows_vm_name" {
  value = azurerm_windows_virtual_machine.bastion-windows-vm.name
}

# Windows VM Admin Username
output "bastion_windows_vm_admin_username" {
  value = var.bastion-windows-admin-username
}

# Windows VM Admin Password (sensitive)
output "bastion_windows_vm_admin_password" {
  value     = var.bastion-windows-admin-password
  sensitive = true
}

# Windows VM Public IP
output "bastion_windows_vm_public_ip" {
  value = azurerm_public_ip.bastion-windows-vm-ip.ip_address
}