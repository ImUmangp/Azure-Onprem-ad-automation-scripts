#Summary
#This PowerShell script is designed to extract stale device details from Microsoft Intune using Microsoft Graph API. 
#The script connects to Intune via a custom application registered in Azure Active Directory (AAD) and retrieves device details, exporting them to a CSV file.
#Step 1: Register a Custom APP on Entra ID
#Step 2: Set API Permissions
#Step 3: Add a Client Secret
#Step 4: Use the App Details in Script

# Define the Application (Client) ID and Secret
$ApplicationClientId = '' # Application (Client) ID
$ApplicationClientSecret = '' # Application Secret Value
$TenantId = '' # Tenant ID


$SecureClientSecret = ConvertTo-SecureString -String $ApplicationClientSecret -AsPlainText -Force


$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationClientId, $SecureClientSecret

s
Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential

# Fetch all managed devices in Intune with specified properties
$devices = Get-MgDeviceManagementManagedDevice -Select "deviceName, lastSyncDateTime"


$devices | Select-Object DeviceName, lastSyncDateTime

# Export the results to a CSV file
$devices | Select-Object DeviceName, lastSyncDateTime | Export-Csv -Path "C:\intuneModificationScript\ManagedDevices.csv" -NoTypeInformation
Write-Output "Device Details Extraction completed. Check the file at C:\intuneModificationScript\ManagedDevices.csv for details."
