# Import necessary modules
Import-Module ActiveDirectory
Import-Module GroupPolicy

# Define timestamp for the log file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = "C:\OUObject\ouDeleteLog_$timestamp.txt"

# Start transcript logging
Start-Transcript -Path $logPath

# Read Distinguished Names of OUs from CSV file
$csvPath = "C:\Users\Umang.Pandey\Documents\OU Deletion\ouDistinguishedNames.csv"  # Update with the correct path to your CSV file
$OUlist = Import-Csv -Path $csvPath

# Function to get all child objects in an OU
function Get-AllChildObjects {
    param (
        [string]$SearchBase
    )
    return Get-ADObject -Filter * -SearchBase $SearchBase -SearchScope Subtree
}

# Proceed with deletion of objects, GPO links, and the OUs themselves
foreach ($OU in $OUlist) {
    $ouDN = $OU.DistinguishedName  # Assuming the CSV has a "DistinguishedName" column
    Write-Host "Processing OU: $ouDN"

    # Check if the OU exists
    try {
        $ouObject = Get-ADOrganizationalUnit -Identity $ouDN -ErrorAction Stop
    } catch {
        Write-Host "Error: OU not found - $ouDN"
        Write-Host "Skipping $ouDN and moving to the next OU."
        continue  # Skip this iteration and move to the next OU
    }

    # 1. Get all child objects in the OU (including nested OUs)
    $allObjects = Get-AllChildObjects -SearchBase $ouDN

    # 2. Disable protection from accidental deletion for all child objects and OUs
    foreach ($obj in $allObjects) {
        try {
            Set-ADObject -Identity $obj.DistinguishedName -ProtectedFromAccidentalDeletion $false
            Write-Host "Disabled protection from accidental deletion for: $($obj.DistinguishedName)"
        } catch {
            Write-Host "Error disabling protection for: $($obj.DistinguishedName) - $_"
        }
    }

    # 3. Delete all child objects, starting with non-OUs (users, computers, groups) first
    foreach ($obj in $allObjects) {
        if ($obj.ObjectClass -ne "organizationalUnit") {
            try {
                Remove-ADObject -Identity $obj.DistinguishedName -Confirm:$false
                Write-Host "Deleted object: $($obj.DistinguishedName)"
            } catch {
                Write-Host "Error deleting object: $($obj.DistinguishedName) - $_"
            }
        }
    }

    # 4. Finally, disable protection and delete the OU (with -Recursive to remove child OUs)
    try {
        Set-ADObject -Identity $ouDN -ProtectedFromAccidentalDeletion $false
        Write-Host "Disabled protection from accidental deletion for OU: $ouDN"
        Remove-ADOrganizationalUnit -Identity $ouDN -Recursive -Confirm:$false
        Write-Host "Deleted OU: $ouDN"
    } catch {
        Write-Host "Error deleting OU: $ouDN - $_"
    }
}

# Stop transcript logging
Stop-Transcript
