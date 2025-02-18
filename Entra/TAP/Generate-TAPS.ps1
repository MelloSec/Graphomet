[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$UserFile,   # Path to CSV file with users

    [Parameter(Mandatory=$true)]
    [string]$OutputFile,  # Path to save results

    [Parameter(Mandatory=$true)]
    [string]$LogFile  # Path to save log
)

# Prompt for Client ID, Tenant ID, and Client Secret
$secureClientId = Read-Host "Enter Client ID" -AsSecureString
$secureTenantId = Read-Host "Enter Tenant ID" -AsSecureString
$secureClientSecret = Read-Host "Enter Client Secret" -AsSecureString

# Convert Secure Strings to Plain Text
$clientId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureClientId))
$tenantId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureTenantId))
$clientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureClientSecret))

# Generate Access Token (Client Credentials Flow)
$body = @{
    grant_type    = "client_credentials"
    scope         = "https://graph.microsoft.com/.default"
    client_id     = $clientId
    client_secret = $clientSecret
}

$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $body
$accessToken = $tokenResponse.access_token

Write-Output "Access Token Acquired Successfully!"

# Set Authorization Header
$Headers = @{Authorization = "Bearer $accessToken"}

# Import Users from CSV
$users = (Import-Csv -Path $UserFile).UserName

# Initialize Hash Table to Store Output
$hash = @{}
$log = @()

# Generate Temporary Access Pass (TAP) for Each User
ForEach ($user in $users) {
    $tapUri = "https://graph.microsoft.com/beta/users/$user/authentication/temporaryAccessPassMethods"
    $body = "{}"
    
    Try {
        $tapResponse = Invoke-RestMethod -Headers $Headers -Uri $tapUri -Body $body -Method POST -ContentType "application/json"
        $tap = $tapResponse.temporaryAccessPass
        $hash.add($user, $tap)
        Write-Output "TAP created for $user"
        
        # Log the TAP creation
        $log += [PSCustomObject]@{
            DateTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
            UserName = $user
            Status = "Success"
        }
    }
    Catch {
        Write-Output "Error creating TAP for $user"
        
        # Log the error
        $log += [PSCustomObject]@{
            DateTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
            UserName = $user
            Status = "Error"
        }
    }
}

# Save Results to CSV
$hash.GetEnumerator() | Select-Object -Property @{N='User Name';E={$_.Key}}, @{N='Temporary Access Pass';E={$_.Value}} | Export-Csv -Path $OutputFile -NoTypeInformation

# Append Log to CSV
if (Test-Path $LogFile) {
    $log | Export-Csv -Path $LogFile -NoTypeInformation -Append
} else {
    $log | Export-Csv -Path $LogFile -NoTypeInformation
}

Write-Output "Temporary Access Passes saved to $OutputFile"
Write-Output "Log saved to $LogFile"