# ============================================================
# FASE 2 - EJECUTAR DESPUÉS DEL REINICIO (PowerShell como Admin)
# Cambia la letra del disco temporal de D: a T:
# ============================================================

Write-Host "FASE 2: Cambiando letra Temporary Storage D: → T:" -ForegroundColor Cyan

# Método principal recomendado (CimInstance)
$success = $false
try {
    $drive = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = 'D:'" -ErrorAction Stop
    if ($drive) {
        $drive | Set-CimInstance -Property @{ DriveLetter = 'T:' } -ErrorAction Stop
        Write-Host "✓ Letra cambiada a T: usando Set-CimInstance" -ForegroundColor Green
        $success = $true
    }
} catch {
    Write-Host "CIM falló: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Método alternativo si el anterior falló
if (-not $success) {
    try {
        Get-Partition -DriveLetter D -ErrorAction Stop |
            Set-Partition -NewDriveLetter T -ErrorAction Stop
        Write-Host "✓ Letra cambiada usando Set-Partition" -ForegroundColor Green
        $success = $true
    } catch {
        Write-Host "Set-Partition también falló: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Ver resultado
Start-Sleep -Seconds 2
Write-Host ""
Write-Host "Estado actual de unidades:" -ForegroundColor Cyan
Get-Volume | Where-Object { $_.DriveLetter } |
    Select-Object DriveLetter, FileSystemLabel, 
        @{N='Size (GB)'; E={[math]::Round($_.Size/1GB,1)}}, 
        @{N='Free (GB)'; E={[math]::Round($_.SizeRemaining/1GB,1)}} |
    Format-Table -AutoSize

if ($success) {
    Write-Host ""
    Write-Host "¡Listo! Ahora deberías tener D: libre." -ForegroundColor Green
    Write-Host "Recomendado: Reinicia una vez más." -ForegroundColor Yellow
    Write-Host "Para mover también el pagefile a T: ejecuta:" -ForegroundColor Gray
    Write-Host '  Get-WmiObject Win32_PageFileSetting | ? Name -like "C:*" | % { $_.Delete() }'
    Write-Host '  Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name="T:\pagefile.sys";InitialSize=0;MaximumSize=0}'
    Write-Host '  Restart-Computer -Force'
}
