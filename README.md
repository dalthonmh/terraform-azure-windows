Deploying a Azure Windows VM (catastro)
============

Deploy a Windows VM named 'catastro':

- Region: Canada Central
- Image: Windows Server 2022 Datacenter: Azure Edition - x64 Gen2 (`2022-datacenter-azure-edition`)
- Size: Standard_B4ms (4 vCPU, 16 GiB)
- Admin: azureuser
- No infrastructure redundancy (simple deployment)

Update values in terraform.tfvars (credenciales Azure + password) antes de hacer `terraform apply`.

Connect via RDP usando la IP pública que sale en los outputs + usuario `azureuser`.

Sample code compatible with **AzureRM v3+ / v4+**
