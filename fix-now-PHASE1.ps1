# ============================================================
# FASE 1 - EJECUTAR EN POWERSHELL COMO ADMINISTRADOR
# Mueve el pagefile de D: a C: (necesario para poder cambiar la letra)
# ============================================================

Write-Host "FASE 1: Preparando cambio de Temporary Storage (D: -> T:)" -ForegroundColor Cyan

# 1. Deshabilitar pagefile automático
$cs = Get-WmiObject Win32_ComputerSystem
$cs.AutomaticManagedPagefile = $false
$cs.Put() | Out-Null
Write-Host "✓ AutomaticManagedPagefile = False" -ForegroundColor Green

# 2. Borrar pagefile que esté en D:
Get-WmiObject Win32_PageFileSetting -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'D:*' } |
    ForEach-Object {
        $_.Delete() | Out-Null
        Write-Host "✓ Pagefile eliminado de D:" -ForegroundColor Green
    }

# 3. Poner pagefile en C: (tamaño administrado por el sistema)
Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{
    Name = 'C:\pagefile.sys'
    InitialSize = 0
    MaximumSize = 0
} | Out-Null
Write-Host "✓ Pagefile configurado en C:\" -ForegroundColor Green

Write-Host ""
Write-Host "FASE 1 lista. La máquina se reiniciará en 5 segundos..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
Restart-Computer -Force
