## Intune Notes

### Assign-ManagedApps.ps1 - Select and Assign Intune Apps to Groups
Use an app registration to with required permissions to Include/Exclude and deploy Available/Required Intune apps by Group

```powershell
 .\Assign-ManagedApps.ps1 -GroupPrefix "All Users" -Intent "Available" -iOs
```


### OData Types and Request Templates
```
OData Type	Description
#microsoft.graph.win32LobApp	Win32 LOB app
#microsoft.graph.microsoftStoreForBusinessApp	Microsoft Store for Business app
#microsoft.graph.windowsUniversalAppX	Windows Universal AppX app
#microsoft.graph.iosLobApp	iOS LOB app
#microsoft.graph.iosStoreApp	iOS App Store app
#microsoft.graph.androidLobApp	Android LOB app
#microsoft.graph.androidStoreApp	Android Google Play Store app
#microsoft.graph.mobileLobApp	Generic mobile LOB app
#microsoft.graph.officeSuiteApp	Microsoft 365 (Office) app
#microsoft.graph.webApp	Web-based application
#microsoft.graph.macOSLobApp	macOS LOB app
#microsoft.graph.macOSMicrosoftEdgeApp	Microsoft Edge for macOS
#microsoft.graph.managedAndroidLobApp	Android LOB app managed by Intune
#microsoft.graph.managedIOSLobApp	iOS LOB app managed by Intune
#microsoft.graph.managedMobileLobApp	Generic managed mobile LOB app
```