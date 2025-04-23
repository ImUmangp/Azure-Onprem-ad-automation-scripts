# Ensure you are running as a Domain Admin or with sufficient rights

# Import Active Directory module
Import-Module ActiveDirectory

# Get all computer accounts
$computers = Get-ADComputer -Filter * -Property Name, OperatingSystem | Where-Object {
    $_.OperatingSystem -like "*Server*"
}

# Prepare results array
$results = @()

foreach ($comp in $computers) {
    $serverName = $comp.Name
    Write-Host "Checking $serverName..." -ForegroundColor Cyan

    try {
        # Invoke remote WMI query
        $wmi = Get-WmiObject -Class SoftwareLicensingProduct -ComputerName $serverName `
            -Filter "Name like 'Windows%'" -ErrorAction Stop
         # Query SoftwareLicensingProduct via CIM for activation status
        $cimData = Get-CimInstance -ClassName SoftwareLicensingProduct -ComputerName $serverName `
            -Filter "Name LIKE 'Windows%'" -ErrorAction Stop
        foreach ($item in $wmi) {
            if ($item.PartialProductKey) {
                $results += [PSCustomObject]@{
                    ServerName       = $serverName
                    ProductName      = $item.Name
                    LicenseStatus    = $item.LicenseStatus
                    PartialKey       = $item.PartialProductKey
                    Description      = $item.Description
                    LastCommunication = (Get-Date)
                }
            }
        }
    }
    catch {
        $results += [PSCustomObject]@{
            ServerName       = $serverName
            ProductName      = "N/A"
            LicenseStatus    = "Unreachable"
            PartialKey       = "N/A"
            Description      = $_.Exception.Message
            LastCommunication = "Failed"
        }
    }
}

# Output to console and export to CSV
$results | Format-Table -AutoSize
$results | Export-Csv -Path "C:\ServerActivationStatus.csv" -NoTypeInformation

Write-Host "Script complete. Output saved to C:\ServerActivationStatus.csv" -ForegroundColor Green
