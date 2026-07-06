Deploying a Azure Windows VM (catastro)
============

Deploy a Windows VM named 'catastro':

- Region: Canada Central
- Image: Windows Server 2022 Datacenter: Azure Edition - x64 Gen2 (`2022-datacenter-azure-edition`)
- Size: Standard_B4ms (4 vCPU, 16 GiB)
- Admin: azureuser
- No infrastructure redundancy (simple deployment)

El aprovisionamiento incluye lógica (CustomScriptExtension + Scheduled Task "Azure-SetTempDrive") para mover el **Temporary Storage** de **D:** a **T:**.

## Si después del deploy sigue apareciendo "Temporary Storage" en D:

1. Copia el archivo `fix-temp-storage-drive.ps1` (incluido en este repo) a la VM o pégalo completo en un archivo nuevo.
2. Abre **PowerShell como Administrador**.
3. Ejecuta:
   ```powershell
   .\fix-temp-storage-drive.ps1
   ```
4. La VM se reiniciará (Fase 1: mueve pagefile a C:).
5. Vuelve a conectarte por RDP y ejecuta el mismo comando de nuevo (Fase 2: cambia la letra D: → T:).
6. (Opcional) Reinicia una vez más.

Después de esto **D:** debe quedar libre (puedes verificarlo con `Get-Volume` o `diskmgmt.msc`).

Update values in terraform.tfvars (credenciales Azure + password) antes de hacer `terraform apply`.

Connect via RDP usando la IP pública que sale en los outputs + usuario `azureuser`.

Sample code compatible with **AzureRM v3+ / v4+**
