#This PowerShell script facilitates the deletion of stale devices from Microsoft Intune.
#It leverages Microsoft Graph API to authenticate and manage devices listed in a specified CSV file, ensuring efficient removal of devices that are no longer active
#1.Register a custom app in Azure Active Directory (AAD).
#2.Set API permissions for Microsoft Graph.
#3.Add a client secret.
#4.Verify CSV File


# Define the Application (Client) ID and Secret
$ApplicationClientId = '' # Application (Client) ID
$ApplicationClientSecret = '' # Application Secret Value
$TenantId = '' # Tenant ID


$SecureClientSecret = ConvertTo-SecureString -String $ApplicationClientSecret -AsPlainText -Force

$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationClientId, $SecureClientSecret

Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential

# Log File Path
$logFilePath = "C:\intuneModificationScript\DeviceDeletionLog.txt"
"Device Deletion Process Started: $(Get-Date)" | Out-File -FilePath $logFilePath

# Import the CSV file containing Device Names
$csvDevices = Import-Csv -Path "C:\intuneModificationScript\ManagedDevices1.csv"

foreach ($device in $csvDevices) {
    $deviceName = $device.DeviceName
    
    
    $deviceToDelete = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$deviceName'"
    
    if ($deviceToDelete) {
        
        Write-Output "Deleting device: $deviceName (ID: $($deviceToDelete.Id))"
        Write-Output "Deleting device: $deviceName (ID: $($deviceToDelete.Id))" | Out-File -Append -FilePath $logFilePath
        
        
        Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceToDelete.Id -Confirm:$false
        
        
        "Successfully deleted device: $deviceName (ID: $($deviceToDelete.Id))" | Out-File -Append -FilePath $logFilePath
    } else {
        
        Write-Output "Device not found: $deviceName"
        "Device not found or does not match: $deviceName" | Out-File -Append -FilePath $logFilePath
    }
}


"Device Deletion Process Completed: $(Get-Date)" | Out-File -Append -FilePath $logFilePath


#Disconnect-MgGraph


Write-Output "Device deletion process completed. Check the log file at $logFilePath for details."
