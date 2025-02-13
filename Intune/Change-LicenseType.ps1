[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
    [string]$appId,

    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
    [string]$groupID,

    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
    [string]$licenseType
)

function Change-LicenseType {
    param (
        [string]$appId,
        [string]$groupID,
        [string]$licenseType
    )

    $apiUrl = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$appId/assignments"
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method GET

    # Display the full response for manual inspection
    $response | fl *

    # Delete the existing assignment
    $assignmentId = ($response.value | Where-Object { $_.target.groupId -eq $groupID }).id
    if ($assignmentId) {
        $deleteUrl = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$appId/assignments/$assignmentId"
        Invoke-RestMethod -Uri $deleteUrl -Headers $headers -Method DELETE
        Write-Output "Deleted the existing assignment with ID: $assignmentId"
    } else {
        Write-Output "No existing assignment found for Group ID: $groupID"
    }

    # Assign the new license type
    $useDeviceLicensing = $licenseType -eq 'device'

    $bodyTemplate = @{
        target = @{
            "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
            groupId = $groupID
        }
        intent = "required"
        settings = @{
            "@odata.type" = "#microsoft.graph.iosVppAppAssignmentSettings"
            useDeviceLicensing = $useDeviceLicensing
        }
    }

    $jsonBody = $bodyTemplate | ConvertTo-Json -Depth 10 -Compress
    $apiUrl = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$appId/assignments"

    Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method POST -Body $jsonBody -ContentType "application/json"

    Write-Output "License type changed successfully to: $licenseType"
}
