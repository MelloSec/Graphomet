$secureClientId = Read-Host "Enter Client ID" -AsSecureString
$secureTenantId = Read-Host "Enter Tenant ID" -AsSecureString
$secureClientSecret = Read-Host "Enter Client Secret" -AsSecureString

# Convert secure strings to plain text
$plainClientId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureClientId))
$plainTenantId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureTenantId))
#$plainTenantID = $secureTenantId
$plainClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureClientSecret))

$clientId = $plainClientId
$tenantId = $plainTenantId
$clientSecret = $plainClientSecret

Write-Output "Acquiring Access Token for Graph"

$body = @{
    grant_type    = "client_credentials"
    scope         = "https://graph.microsoft.com/.default"
    client_id     = $clientId
    client_secret = $clientSecret
}
$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $body
$accessToken = $tokenResponse.access_token

# Convert access token to a SecureString
$secureAccessToken = ConvertTo-SecureString -String $accessToken -AsPlainText -Force

# Construct the authorization headers using the access token
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

# $appId = 
# Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/<appId>" -Headers $headers -Method GET