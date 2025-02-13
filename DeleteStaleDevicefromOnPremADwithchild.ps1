#This PowerShell script automates the deletion of stale devices and all their child objects from on-premises Active Directory (AD). 
#It ensures a comprehensive cleanup by recursively deleting child objects before removing the parent device object.
#Prerequisites
#1.	Ensure the Active Directory module is imported in the PowerShell session.
#2.	Prepare a CSV file (StaleDevices.csv) containing a Name column with the names of the stale devices to be deleted.

# Parameters
$InputFile = "StaleDevices.csv" # Specify the input CSV file name containing stale device names
$LogFile = "DeletedDevices.log" # Specify a log file to keep track of deleted devices

# Import Active Directory module
Import-Module ActiveDirectory

# Read the CSV file
if (-Not (Test-Path $InputFile)) {
    Write-Host "Input file '$InputFile' not found." -ForegroundColor Red
    exit
}

$DevicesToDelete = Import-Csv -Path $InputFile

# Ensure the CSV has the correct format
if (-Not ($DevicesToDelete | Get-Member -Name Name)) {
    Write-Host "The CSV file must contain a 'Name' column." -ForegroundColor Red
    exit
}

# Create/Append to log file
"Deleted Devices Log - $(Get-Date)" | Out-File -FilePath $LogFile -Encoding UTF8 -Append

# Function to recursively delete child objects
function Delete-ADObjectRecursive {
    param (
        [string]$DistinguishedName
    )

    # Get child objects
    $ChildObjects = Get-ADObject -Filter * -SearchBase $DistinguishedName -SearchScope OneLevel

    foreach ($Child in $ChildObjects) {
        # Recursive call to delete child objects
        Delete-ADObjectRecursive -DistinguishedName $Child.DistinguishedName
        
        try {
            # Delete the child object
            Remove-ADObject -Identity $Child.DistinguishedName -Confirm:$false
            Write-Host "Deleted child object: $($Child.DistinguishedName)" -ForegroundColor Green
            "$($Child.DistinguishedName) - Deleted Successfully" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
        } catch {
            Write-Host "Failed to delete child object: $($Child.DistinguishedName). Error: $_" -ForegroundColor Red
            "$($Child.DistinguishedName) - Deletion Failed. Error: $_" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
        }
    }
}

# Loop through each device and delete it
foreach ($Device in $DevicesToDelete) {
    $DeviceName = $Device.Name

    $ADObject = Get-ADComputer -Filter {Name -eq $DeviceName} -Properties DistinguishedName

    if (-Not $ADObject) {
        Write-Host "Device '$DeviceName' not found in Active Directory." -ForegroundColor Yellow
        "$DeviceName - Not Found" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
        continue
    }

    # Delete child objects first
    Delete-ADObjectRecursive -DistinguishedName $ADObject.DistinguishedName

    try {
        # Attempt to delete the parent device object
        Remove-ADComputer -Identity $ADObject.DistinguishedName -Confirm:$false
        Write-Host "Device '$DeviceName' deleted successfully." -ForegroundColor Green
        "$DeviceName - Deleted Successfully" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
    } catch {
        Write-Host "Failed to delete device '$DeviceName'. Error: $_" -ForegroundColor Red
        "$DeviceName - Deletion Failed. Error: $_" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
    }
}

Write-Host "Device deletion process completed. Check the log file '$LogFile' for details." -ForegroundColor Cyan
