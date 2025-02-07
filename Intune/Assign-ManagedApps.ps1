[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]$GroupPrefix,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]$Intent
)

<#
.DESCRIPTION
    This section defines the required Azure App Registration, Microsoft Graph API permissions, 
    and necessary PowerShell modules for interacting with Microsoft Intune, Groups, and Device Management.

.REQUIREMENTS
    - Azure App Registration
    - Microsoft Graph API Permissions
    - Admin Consent
    - Microsoft Graph PowerShell Modules

.PERMISSIONS
    The following Microsoft Graph API application permissions must be assigned:

    - Device.Read.All                    # Read all devices
    - Device.ReadWrite.All               # Read and write devices
    - DeviceManagementApps.ReadWrite.All # Read and write Microsoft Intune apps
    - DeviceManagementConfiguration.ReadWrite.All # Read and write Microsoft Intune device configurations and policies
    - DeviceManagementManagedDevices.ReadWrite.All # Read and write Microsoft Intune devices
    - Directory.Read.All                 # Read directory data
    - Group.Read.All                     # Read all groups
    - Group.ReadWrite.All                # Read and write all groups
    - GroupMember.Read.All               # Read all group memberships
    - User.Read                          # Sign in and read user profile (delegated)
    - User.Read.All                      # Read all users' full profiles

.CLIENT SECRET
    - A client secret must be generated and stored securely.
    - This is required for authentication when accessing Microsoft Graph API.

.ADMIN CONSENT
    - Admin consent must be granted to approve the assigned permissions.
    - This ensures the application has the necessary access to Microsoft Graph resources.

.INSTALLATION
    The following PowerShell modules must be installed:

    Install-Module Microsoft.Graph.DeviceManagement -Force
    Install-Module Microsoft.Graph.Intune -Force
    Install-Module Microsoft.Graph.Groups -Force

.IMPORT MODULES
    Import only the required Microsoft Graph submodules:

    Import-Module Microsoft.Graph.Groups -Force
    Import-Module Microsoft.Graph.Intune -Force
    Import-Module Microsoft.Graph.DeviceManagement -Force

.EXAMPLE
    To Assign Apps, provide a partial Group name and whether it should be "Available" or "required"

    .\Assign-ManagedApps.ps1 -GroupPrefix "All Users" -Intent "Available"
#>

#### Begin Setting Variables ####

# Optionally define a prefix to filter the group names from the selection dialog box.
$GroupPrefix = $GroupPrefix

# Define the log file path
$LogFile = ".\IntuneAssignmentScript-$(Get-Date -UFormat "%m-%d-%Y_%H-%m").log"
# Create log file if it doesn't exist
if (-not (Test-Path $LogFile)) {
    New-Item -Path $LogFile -ItemType File -Force
}

# Initialize counters to track the number of assignments processed, succeeded, and failed
$processedCount = 0
$successCount = 0
$failureCount = 0

#### End Setting Variables ####

######## Begin Functions ########

####################################################
# Function to log messages to a log file and to the screen
function Log-Message {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $logEntry

    switch ($Level) {
        "ERROR" { Write-Error $Message }
        default { Write-Host $Message }
    }
}

####################################################
# Function to get the group from Graph.
function Select-Group {
    <#
    .SYNOPSIS
    Retrieves groups from Graph and allows selection via GridView.

    .DESCRIPTION
    This function retrieves groups from Azure AD based on an optional prefix and displays them in a GridView for selection.

    .PARAMETER GroupPrefix
    The prefix to filter groups by their display name.
    #>
    
    param (
        [string]$GroupPrefix
    )
    Log-Message $GroupPrefix

    if ($GroupPrefix) {
        Log-Message "Getting groups starting with $($GroupPrefix)"
        $Groups = Get-MgGroup -Filter "startswith(DisplayName, '$GroupPrefix')" -Property DisplayName, Id
    }
    else {
        Log-Message "Getting all groups"
        $Groups = Get-MgGroup -Property DisplayName, Id
    }

    if ($Groups.Count -eq 0) {
        Log-Message "No groups found with the given prefix." "ERROR"
        return $null
    }

    # Customizing the output to display only DisplayName
    $TargetGroup = $Groups.DisplayName | Out-GridView -Title "Select a Single Group:" -OutputMode Single

    # Retrieve the Id based on the selected DisplayName
    $GroupId = $Groups | Where-Object { $_.DisplayName -eq $TargetGroup } | Select-Object -ExpandProperty Id

    if ($TargetGroup -and $GroupId) {
        Log-Message "Target Group Name: $($TargetGroup)"
        Log-Message "Target Group ID: $($GroupId)"
        return [PSCustomObject]@{
            DisplayName = $TargetGroup
            Id          = $GroupId
        }
    }
    else {
        Log-Message "No group selected. Please select a group to proceed." "ERROR"
        return $null
    }
}

####################################################
# Function to ensure modules are installed and updated
function Assert-ModuleExists {
    <#
    .SYNOPSIS
    Ensures the specified module is installed and up to date.

    .DESCRIPTION
    This function checks if a specified module is installed and up to date. If not, it installs or updates the module.

    .PARAMETER ModuleName
    The name of the module to check, install, or update.
    #>
    
    param (
        [string]$ModuleName
    )

    $installedModule = Get-Module -Name $ModuleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    $latestModule = Find-Module -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1

    if ($installedModule) {
        if ($latestModule) {
            if ($installedModule.Version -lt $latestModule.Version) {
                Log-Message "Updating module $ModuleName ..."
                Update-Module -Name $ModuleName -Force
                Log-Message "Module updated to version $($latestModule.Version)"
            }
            else {
                Log-Message "Module $ModuleName is already up to date."
            }
        }
        else {
            Log-Message "Module $ModuleName is not found in the repository." "ERROR"
        }
    }
    else {
        Log-Message "Installing module $ModuleName ..."
        Install-Module -Name $ModuleName -Force
        Log-Message "Module installed"
    }
}

####################################################
# Function to select an option from a list
function Select-Option {
    <#
    .SYNOPSIS
    Displays a list of choices in a GridView for user selection.

    .DESCRIPTION
    This function displays a list of choices in a GridView for user selection and returns the selected choice.

    .PARAMETER Choices
    The list of choices to display.

    .PARAMETER Title
    The title of the GridView window.
    #>
    
    param (
        [string[]]$Choices,
        [string]$Title
    )

    $selectedChoice = $Choices | Out-GridView -Title $Title -OutputMode Single -ErrorAction SilentlyContinue
    if ($selectedChoice) {
        return $selectedChoice
    }
    else {
        Log-Message "No option selected. Please select an option." "ERROR"
        return $null
    }
}
####################################################
######## End Functions ########

######## Script Entry Point ########

# Install required modules
Log-Message "Checking whether Microsoft.Graph.Beta.Groups module is installed"
Assert-ModuleExists -ModuleName 'Microsoft.Graph.Beta.Groups'

Log-Message "Checking whether Microsoft.Graph.Authentication module is installed"
Assert-ModuleExists -ModuleName 'Microsoft.Graph.Authentication'

Log-Message "Checking whether Microsoft.Graph.Devices.CorporateManagement is installed"
Assert-ModuleExists -ModuleName 'Microsoft.Graph.Devices.CorporateManagement'


# Connect to Graph
# Get an access token
# Convert secure strings to plain text
# Read in the client ID, tenant ID, and client secret as secure strings
$secureClientId = Read-Host "Enter Client ID" -AsSecureString
$secureTenantId = Read-Host "Enter Tenant ID" -AsSecureString
$secureClientSecret = Read-Host "Enter Client Secret" -AsSecureString

# Convert secure strings to plain text
$plainClientId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureClientId))
$plainTenantId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureTenantId))
$plainClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureClientSecret))

$clientId = $plainClientId
$tenantId = $plainTenantId
$clientSecret = $plainClientSecret


# Use the plain text values in your script
Write-Host "Tenant ID: $TenantId"

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

# Connect to Microsoft Graph using SecureString Access Token

$context = Get-MgContext
if (!($context)) {
    Log-Message "Connect to Graph."
    # Connect-MgGraph -ClientId $clientId -TenantId $TenantId -NoWelcome
    Connect-MgGraph -AccessToken $secureAccessToken -NoWelcome
}
Log-Message "Connected to Graph"
Log-Message "Scopes: $($context.Scopes)"

# Get the app(s) from Intune
Log-Message "Getting Apps from Intune. Be patient, this can take a while."

#  $Apps = Get-MgDeviceAppMgtMobileApp -ExpandProperty Assignments | select DisplayName, Id | Sort-Object
$Apps = Get-MgDeviceAppMgtMobileApp -ExpandProperty Assignments | Where-Object { 
    $_.AdditionalProperties.'@odata.type' -in @("#microsoft.graph.webApp", "#microsoft.graph.managedIOSStoreApp", "#microsoft.graph.iosVppApp")
} | Select-Object DisplayName, Id, AdditionalProperties | Sort-Object DisplayName

$selectedApps = $Apps | Out-GridView -PassThru -Title "Select App(s) You Want to Assign:" 
$appIds = $selectedApps | select -ExpandProperty Id

if (!($appIds)) {
    Log-Message "No apps selected!" "ERROR"
    Return
}

# Get groups and display them in GridView for user selection
Log-Message "Getting groups from Graph"
# Get the group
$selectedGroup = Select-Group -GroupPrefix $GroupPrefix
if ($selectedGroup) {
    $GroupId = $selectedGroup.Id
    $GroupName = $selectedGroup.DisplayName
    Log-Message "Selected Group ID: $GroupId"
    Log-Message "Selected Group Name: $GroupName"
}
else {
    Log-Message "No group selected." "ERROR"
    Return
}

# Determine the assignment type
$AssignmentChoices = "Include", "Exclude"
$selectedChoice = Select-Option -Choices $AssignmentChoices -Title "Select Deployment Type:"
if (-not $selectedChoice) {
    Log-Message "No option selected. Please select either 'Include' or 'Exclude'." "ERROR"
    Return
}

# Set the variable based on the selected choice
if ($selectedChoice -eq "Include") {
    $DeployType = "Included"
}
elseif ($selectedChoice -eq "Exclude") {
    $DeployType = "Excluded"
}

# Output the selected group and deployment type
Log-Message "The selected group: $GroupId will be $DeployType"

# Only prompt for filter if the deployment type is Include
$FilterId = $null
$FilterType = $null
$FilterName = $null

if ($selectedChoice -eq 'Include') {
    # Make the API request to get assignment filters
    $filtersResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters" -Method Get

    # Check the content of the response
    if ($filtersResponse -and $filtersResponse.value) {
        $filters = $filtersResponse.value

        # Extract DisplayName and Id from the hashtables
        $extractedFilters = $filters | ForEach-Object {
            [PSCustomObject]@{
                DisplayName = $_.DisplayName
                Id          = $_.Id
            }
        }

        # Debugging: Output the extracted filters data
        $extractedFilters | ForEach-Object { Write-Host "DisplayName: $($_.DisplayName), Id: $($_.Id)" }

        # Select DisplayName and Id properties and pipe to Out-GridView
        $selectedFilter = $extractedFilters | Out-GridView -Title "Select an Assignment Filter (Optional):" -OutputMode Single

        # Debugging: Check if a filter was selected
        if ($selectedFilter) {
            Log-Message "Selected Filter DisplayName: $($selectedFilter.DisplayName)"
            Log-Message "Selected Filter Id: $($selectedFilter.Id)"
        }
        else {
            Log-Message "No filter type selected. Please select a filter type." "ERROR"
        }
    }
    else {
        Log-Message "No filters found or API request failed." "ERROR"
    }

    if ($selectedFilter) {
        $FilterId = $selectedFilter.Id
        $FilterName = $selectedFilter.DisplayName
        Log-Message "Selected Filter ID: $FilterId"
        Log-Message "Selected Filter Name: $FilterName"

        # Determine the filter type
        $FilterTypeChoices = "Include", "Exclude"
        $FilterType = Select-Option -Choices $FilterTypeChoices -Title "Select Filter Type:"
        if (-not $FilterType) {
            
            Return
        }
    }
}

# Create the request body depending upon whether it will be an include or exclude assignment.
if ($selectedChoice -eq 'Exclude') {
    # Define the request body template for exclude assignment
    Log-Message "Defining body template for Graph calls to exclude group."
    $bodyTemplate = @{
        target        = @{
            groupId       = $GroupId
            "@odata.type" = "microsoft.graph.exclusionGroupAssignmentTarget"
        }
        intent        = "$Intent"
        "@odata.type" = "#microsoft.graph.mobileAppAssignment"
    }
}

if ($selectedChoice -eq 'Include') {
    # Define the request body template for include assignment
    Log-Message "Defining body template for Graph calls to include group."

    # Loop through each app ID
    foreach ($app in $selectedApps) {
        $Id = $app.Id
        $AppName = $app.DisplayName
        $odataType = $app.AdditionalProperties.'@odata.type'

        Write-Output "ODATA Type is $odataType"

        # Debug: Print the app type
        Log-Message "Processing app type: $odataType"

        # Define the API URL with the variable for the assignment ID
        $apiUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$Id/assignments"
        
        # Debug: Print API URL
        Log-Message "API URL: $apiUrl"


        # Create the request body based on the app type
        switch ($odataType) {
            "#microsoft.graph.webApp" {
                $bodyTemplate = @{
                    target   = @{
                        groupId       = $GroupId
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                    intent   = "$Intent"
                    settings = @{
                        "@odata.type" = "#microsoft.graph.webAppAssignmentSettings"
                    }
                }
            }
            "#microsoft.graph.managedIOSStoreApp" {
                $bodyTemplate = @{
                    target   = @{
                        groupId       = $GroupId
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                    intent   = "$Intent"
                    settings = @{
                        "@odata.type" = "#microsoft.graph.iosStoreAppAssignmentSettings"
                    }
                }
            }
            "#microsoft.graph.iosVppApp" {
                $bodyTemplate = @{
                    target   = @{
                        groupId       = $GroupId
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                    intent   = "$Intent"
                    settings = @{
                        "@odata.type" = "#microsoft.graph.iosVppAppAssignmentSettings"
                    }
                }
            }
            default {
                Log-Message "Unsupported app type: $odataType" "ERROR"
                continue
            }
        }

        # Convert the body template to JSON
        $jsonBody = $bodyTemplate | ConvertTo-Json -Depth 3

        # Debug: Print Body, and JSON Body
        Log-Message "Body: $bodyTemplate"
        Log-Message "JSON Body: $jsonBody"

        # Send the POST request
        try {
            $response = Invoke-MgGraphRequest -Uri $apiUrl -Body $jsonBody -Method POST -ContentType "application/json"
            # Output the response
            Log-Message "Response Content: $($response | ConvertTo-Json -Depth 3)"

            # Success message
            Log-Message "The group has been successfully assigned to the app $AppName as an $Intent group at $(Get-Date)."

            # Increment the counter
            $processedCount++
            $successCount++
        }
        catch {
            # Capture and output the error details
            Log-Message "Error: $($_.Exception.Message)" "ERROR"
            
            if ($_.Exception.Response) {
                $responseBody = $null
                try {
                    $responseStream = $_.Exception.Response.RawContentStream
                    $reader = New-Object System.IO.StreamReader($responseStream)
                    $responseBody = $reader.ReadToEnd() | ConvertFrom-Json
                }
                catch {
                    Log-Message "Failed to parse error response content." "ERROR"
                }

                if ($responseBody) {
                    $errorMessage = $responseBody.error.message

                    Log-Message "Response Body: $($responseBody | ConvertTo-Json -Depth 3)" "ERROR"

                    # Check if the error indicates that the assignment already exists
                    if ($errorMessage -match "The MobileApp Assignment already exists") {
                        Log-Message "The MobileApp Assignment already exists for AppName: $($AppName) and AssignmentId: $GroupId" "ERROR"
                    }
                    else {
                        Log-Message "An error occurred for AppName: $($AppName): $errorMessage" "ERROR"
                    }
                }
                else {
                    Log-Message "Error: Unable to parse error response content." "ERROR"
                }
            }
            else {
                Log-Message "Error: No response received." "ERROR"
            }

            # Increment the failure counter
            $failureCount++
        }
    }

    # Write a message after the loop completes
    $summaryMessage = "$processedCount assignments have been processed: $successCount succeeded, $failureCount failed."
    Log-Message $summaryMessage
}

