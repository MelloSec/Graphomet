# Graphomet

Collection of Graph scripts, tools, notes, etc.

### Intune

#### Assign-ManagedApps.ps1 - Select and Assign Intune Apps to Groups
Use an app registration to with required permissions to Include/Exclude and deploy Available/Required Intune apps by Group

```powershell
 .\Assign-ManagedApps.ps1 -GroupPrefix "All Users" -Intent "Available" -iOs
```

```powershell
 .\Assign-ManagedApps.ps1 -GroupPrefix "Intune-" -Intent "Required" -iOs
```

```powershell
 .\Assign-ManagedApps.ps1 -GroupPrefix "Intune-" -Intent "Required" -Windows
```


### IntuneManagement for export/import and OIB deployments

```powershell
$tenant = Read-Host -Prompt "Enter Tenant ID" -AsSecureString
$appId = Read-Host -Prompt "Enter App ID" -AsSecureString
$secret = Read-Host -Prompt "Enter Secret" -AsSecureString

$tenantPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tenant))
$appIdPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($appId))
$secretPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret))

# Start the script with plain text credentials
.\Start-IntuneManagement.ps1 -Tenant $tenantPlainText -AppId $appIdPlainText -Secret $secretPlainText
```