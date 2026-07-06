###############################
## Windows VM (catastro) - Main ##
###############################

# Create Network Security Group to Access Bastion VM from Internet
resource "azurerm_network_security_group" "bastion-windows-nsg" {
  name                = "${var.bastion-windows-vm-hostname}-nsg"
  location            = azurerm_resource_group.bastion-rg.location
  resource_group_name = azurerm_resource_group.bastion-rg.name

  security_rule {
    name                       = "AllowRDP"
    description                = "Allow RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = {
    application = var.app_name
    environment = var.environment
  }
}

# Associate the Bastion NSG with the Subnet
resource "azurerm_subnet_network_security_group_association" "bastion-windows-nsg-association" {
  subnet_id                 = azurerm_subnet.bastion-subnet.id
  network_security_group_id = azurerm_network_security_group.bastion-windows-nsg.id
}

# Get a Static Public IP
resource "azurerm_public_ip" "bastion-windows-vm-ip" {
  name                = "${var.bastion-windows-vm-hostname}-pip"
  location            = azurerm_resource_group.bastion-rg.location
  resource_group_name = azurerm_resource_group.bastion-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = var.environment
  }
}

# Create Network Card for VM
resource "azurerm_network_interface" "bastion-windows-vm-nic" {
  depends_on = [azurerm_public_ip.bastion-windows-vm-ip]

  name                = "${var.bastion-windows-vm-hostname}-nic"
  location            = azurerm_resource_group.bastion-rg.location
  resource_group_name = azurerm_resource_group.bastion-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.bastion-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion-windows-vm-ip.id
  }

  tags = {
    environment = var.environment
  }
}

# Create Windows Server
resource "azurerm_windows_virtual_machine" "bastion-windows-vm" {
  depends_on = [azurerm_network_interface.bastion-windows-vm-nic]

  name                  = var.bastion-windows-vm-hostname
  location              = azurerm_resource_group.bastion-rg.location
  resource_group_name   = azurerm_resource_group.bastion-rg.name
  size                  = var.bastion-windows-vm-size
  network_interface_ids = [azurerm_network_interface.bastion-windows-vm-nic.id]

  computer_name  = var.bastion-windows-vm-hostname
  admin_username = var.bastion-windows-admin-username
  admin_password = var.bastion-windows-admin-password

  os_disk {
    name                 = "${var.bastion-windows-vm-hostname}-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows-2022-azure-edition-sku
    version   = "latest"
  }

  automatic_updates_enabled = true
  provision_vm_agent        = true

  tags = {
    environment = var.environment
  }
}

# Custom Script Extension + Scheduled Task para liberar D: moviendo Temporary Storage a T:
# Usa el patron recomendado (Scheduled Task en startup) porque el Azure Agent puede
# reasignar la letra en el primer arranque. Esto es mucho mas confiable.
resource "azurerm_virtual_machine_extension" "catastro-drive-letter" {
  name                 = "${var.bastion-windows-vm-hostname}-drive-letter"
  virtual_machine_id   = azurerm_windows_virtual_machine.bastion-windows-vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -Command \"${replace(local.setup_drive_script, "\"", "\\\"")}\""
  })

  depends_on = [
    azurerm_windows_virtual_machine.bastion-windows-vm
  ]

  tags = {
    environment = var.environment
  }
}

locals {
  # Este script se ejecuta UNA VEZ durante el aprovisionamiento via CustomScriptExtension.
  # Hace la preparacion (pagefile a C:), escribe el script robusto en disco y
  # crea una Scheduled Task que se ejecutara en cada inicio hasta que complete el cambio.
  setup_drive_script = <<-EOT
$ErrorActionPreference = 'Continue'
Write-Output '=== [1/3] Preparando liberacion de D: (Temporary Storage) ==='

# --- Fase de preparacion: pagefile en C: ---
try {
  $cs = Get-WmiObject Win32_ComputerSystem
  $cs.AutomaticManagedPagefile = $false
  $cs.Put() | Out-Null
  Write-Output 'AutomaticManagedPagefile = False'
} catch {}

Get-WmiObject Win32_PageFileSetting -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like 'D:*' } |
  ForEach-Object { try { $_.Delete() | Out-Null } catch {} }

try {
  Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{
      Name='C:\pagefile.sys'; InitialSize=0; MaximumSize=0
  } | Out-Null
  Write-Output 'Pagefile temporal en C:'
} catch {}

# --- Escribir script robusto que hara el cambio real ---
$scriptDir = 'C:\Scripts'
New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null

$taskScript = @'
$ErrorActionPreference = 'Continue'
$stateFile = 'C:\Scripts\azure-tempdrive.state'
$log = 'C:\Scripts\azure-tempdrive.log'

function Log($m) { "$((Get-Date).ToString('s')) $m" | Out-File $log -Append }

if (Test-Path $stateFile) {
    Log 'Ya completado anteriormente. Saliendo.'
    exit 0
}

$vol = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter='D:'" -ErrorAction SilentlyContinue
if (-not $vol) {
    $vol = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq 'D' -and $_.FileSystemLabel -match 'Temporary' }
}

if ($vol) {
    Log 'Intentando cambiar D: -> T:'
    try {
        $vol | Set-CimInstance -Property @{DriveLetter='T:'} -ErrorAction Stop
        Log 'Cambio de letra exitoso con CIM.'
    } catch {
        Log ('Error CIM: ' + $_.Exception.Message)
        try {
            Get-Partition -DriveLetter D -ErrorAction Stop | Set-Partition -NewDriveLetter T -ErrorAction Stop
            Log 'Cambio exitoso con Set-Partition.'
        } catch { Log ('Error Partition: ' + $_.Exception.Message) }
    }

    # Intentar poner pagefile en T: (opcional pero recomendado)
    try {
        Get-WmiObject Win32_PageFileSetting -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'C:*' } | ForEach-Object { $_.Delete() }
        Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name='T:\pagefile.sys';InitialSize=0;MaximumSize=0} | Out-Null
        Log 'Pagefile movido a T:'
    } catch { Log 'No se pudo mover pagefile a T:' }

    'COMPLETED' | Out-File $stateFile -Force
    Log 'Proceso completado. La tarea se puede deshabilitar.'
} else {
    Log 'No se encontro volumen D: como Temporary Storage.'
    'COMPLETED' | Out-File $stateFile -Force
}
'@

$taskScript | Out-File -FilePath "$scriptDir\Set-AzureTempDrive.ps1" -Encoding UTF8 -Force
Write-Output "Script escrito en $scriptDir\Set-AzureTempDrive.ps1"

# --- Crear Scheduled Task que corre al inicio (SYSTEM) ---
$action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-ExecutionPolicy Bypass -File C:\Scripts\Set-AzureTempDrive.ps1'
$trigger  = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

try {
  Register-ScheduledTask -TaskName 'Azure-SetTempDrive' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
  Write-Output 'Scheduled Task "Azure-SetTempDrive" creada (se ejecutara en el proximo inicio).'
} catch {
  Write-Output ('Error creando tarea: ' + $_.Exception.Message)
}

Write-Output '=== [2/3] Extension terminada. Reiniciando para que la tarea de startup haga el cambio ==='
Start-Sleep -Seconds 5
Restart-Computer -Force
EOT
}