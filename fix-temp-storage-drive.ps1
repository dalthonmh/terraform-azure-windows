<#
.SYNOPSIS
    Libera la unidad D: en VMs de Azure moviendo "Temporary Storage" a T:.

.DESCRIPTION
    Implementa el procedimiento oficial de Microsoft en dos fases con reinicios.

    INSTRUCCIONES (ejecutar en PowerShell como ADMINISTRADOR):

    1. Copia este archivo a la VM (o pégalo completo).
    2. Ejecuta:   .\fix-temp-storage-drive.ps1
       -> Realiza Fase 1 y reinicia la VM.
    3. Vuelve a conectarte por RDP.
    4. Ejecuta de nuevo:   .\fix-temp-storage-drive.ps1
       -> Realiza Fase 2 (cambia la letra), reinicia.
    5. Opcional: Ejecuta una tercera vez si quieres mover el pagefile de nuevo a T:.

    Despues de esto D: debe quedar libre.
#>

param(
    [switch]$ForcePhase2
)

$ErrorActionPreference = 'Continue'
$PhaseFile = 'C:\AzureTempDrive-Phase.txt'
$TEMP_DRIVE = 'D'
$NEW_DRIVE  = 'T'

function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Success($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  AZURE - Mover Temporary Storage D: -> T:" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Verificar si ya esta cambiado
$currentD = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq $TEMP_DRIVE }
if ($currentD -and $currentD.FileSystemLabel -notmatch 'Temporary') {
    Write-Success "D: ya no parece ser Temporary Storage (label: $($currentD.FileSystemLabel))."
    Get-Volume | Where-Object { $_.DriveLetter } | Format-Table DriveLetter, FileSystemLabel, @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}}, @{N='FreeGB';E={[math]::Round($_.SizeRemaining/1GB,1)}} -AutoSize
    exit 0
}

# =========================================
# FASE 1: Mover pagefile a C:
# =========================================
$phase = if (Test-Path $PhaseFile) { Get-Content $PhaseFile -Raw } else { "0" }

if ($phase -ne "2" -and -not $ForcePhase2) {
    Write-Info "=== FASE 1: Moviendo pagefile.sys a C: (requiere reinicio) ==="

    try {
        $cs = Get-WmiObject Win32_ComputerSystem
        $cs.AutomaticManagedPagefile = $false
        $cs.Put() | Out-Null
        Write-Success "  AutomaticManagedPagefile deshabilitado."
    } catch { Write-Warn "  No se pudo cambiar AutomaticManagedPagefile: $_" }

    # Borrar pagefile de D:
    Get-WmiObject Win32_PageFileSetting -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$TEMP_DRIVE`:\*" } |
        ForEach-Object {
            try { $_.Delete() | Out-Null; Write-Success "  Pagefile de $TEMP_DRIVE: eliminado." } catch {}
        }

    # Poner pagefile en C:
    try {
        Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{
            Name = 'C:\pagefile.sys'
            InitialSize = 0
            MaximumSize = 0
        } | Out-Null
        Write-Success "  Pagefile configurado en C:\ (tamaño administrado por sistema)."
    } catch { Write-Warn "  Aviso al configurar pagefile en C:: $_" }

    "2" | Out-File -FilePath $PhaseFile -Encoding ascii -Force

    Write-Host ""
    Write-Warn "FASE 1 completada. La VM se reiniciara en 6 segundos..."
    Start-Sleep -Seconds 6
    Restart-Computer -Force
    exit 0
}

# =========================================
# FASE 2: Cambiar letra de unidad (D: -> T:)
# =========================================
Write-Info "=== FASE 2: Cambiando letra del volumen de D: a T: ==="

# Usar Get-CimInstance + Set-CimInstance (el metodo que mas funciona)
try {
    $volume = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '$TEMP_DRIVE`:'" -ErrorAction Stop
    if ($volume) {
        $volume | Set-CimInstance -Property @{ DriveLetter = "$NEW_DRIVE`:" } -ErrorAction Stop
        Write-Success "  ¡Letra cambiada exitosamente! Ahora el Temporary Storage esta en ${NEW_DRIVE}:"
    } else {
        Write-Warn "  No se encontro volumen con letra $TEMP_DRIVE :"
    }
} catch {
    Write-Warn "  Error usando CIM. Intentando metodo alternativo con Set-Partition..."
    try {
        Get-Partition -DriveLetter $TEMP_DRIVE -ErrorAction Stop |
            Set-Partition -NewDriveLetter $NEW_DRIVE -ErrorAction Stop
        Write-Success "  Letra cambiada con Set-Partition."
    } catch {
        Write-Warn "  Ambos metodos fallaron. Prueba manualmente con diskmgmt.msc"
        Write-Host "  Error: $_"
    }
}

# Verificar resultado
Start-Sleep -Seconds 2
Get-Volume | Where-Object { $_.DriveLetter -in @($TEMP_DRIVE, $NEW_DRIVE) } |
    Format-Table DriveLetter, FileSystemLabel, @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}} -AutoSize

# Limpiar estado
Remove-Item $PhaseFile -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Success "FASE 2 completada."
Write-Warn "Recomendado: Reinicia la VM una vez mas para que todo se estabilice."
Write-Host "Ejecuta:  Restart-Computer -Force" -ForegroundColor White

# =========================================
# OPCIONAL: Mover pagefile de nuevo a T:
# =========================================
Write-Host ""
Write-Host "Si deseas mover el pagefile de vuelta al disco temporal (T:), ejecuta esto despues del reinicio:" -ForegroundColor Gray
Write-Host @'
    Get-WmiObject Win32_PageFileSetting | Where Name -like "C:*" | ForEach { $_.Delete() }
    Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name="T:\pagefile.sys";InitialSize=0;MaximumSize=0}
    Restart-Computer -Force
'@ -ForegroundColor Gray
