[CmdletBinding()]
Param(
    [string]$RepoUrl = "https://github.com/Micke-K/IntuneManagement",
    [string]$RepoPath = ".\IntuneManagement"
)

# Check if Git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed. Please install Git and try again."
    exit 1
}

# Check if IntuneManagement already exists
if (Test-Path $RepoPath) {
    Write-Output "Repository already exists at $RepoPath."
} else {
    Write-Output "Cloning IntuneManagement repository..."
    git clone $RepoUrl $RepoPath
}

# Change directory to the cloned repository
Set-Location $RepoPath

# Secure input for Tenant ID, App ID, and Secret
$tenant = Read-Host -Prompt "Enter Tenant ID" -AsSecureString
$appId = Read-Host -Prompt "Enter App ID" -AsSecureString
$secret = Read-Host -Prompt "Enter Secret" -AsSecureString

# Convert Secure Strings to Plain Text
$tenantPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tenant))
$appIdPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($appId))
$secretPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret))

# Ensure the script file exists
$scriptPath = "$RepoPath\Start-IntuneManagement.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Error "Start-IntuneManagement.ps1 not found in $RepoPath. Exiting..."
    exit 1
}

# Run Start-IntuneManagement.ps1 with credentials
Write-Output "Starting Intune Management Script..."
& $scriptPath -Tenant $tenantPlainText -AppId $appIdPlainText -Secret $secretPlainText
