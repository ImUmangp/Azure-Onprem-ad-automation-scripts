#This PowerShell script is designed to extract details of stale devices from an on-premises Active Directory (AD).
#It identifies devices that have not logged on within a specified number of days and exports their details to a CSV file

# Parameters
$DaysInactive = 90 # Define the number of days to consider a device as stale
$OutputFile = "StaleDevices.csv" # Specify the output CSV file name

# Import Active Directory module
Import-Module ActiveDirectory

# Calculate the date threshold
$ThresholdDate = (Get-Date).AddDays(-$DaysInactive)

# Get stale devices from Active Directory
$StaleDevices = Get-ADComputer -Filter {LastLogonTimestamp -lt $ThresholdDate} -Property Name, OperatingSystem, LastLogonTimestamp | 
    Select-Object Name, OperatingSystem, @{Name="LastLogonDate"; Expression={[datetime]::FromFileTime($_.LastLogonTimestamp)}}

# Export results to CSV
if ($StaleDevices) {
    $StaleDevices | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    Write-Host "Stale devices exported successfully to $OutputFile"
} else {
    Write-Host "No stale devices found in the directory."
}
