#Script Disable User accounts and move with same ou structure within desired Parent OU.
# Import Active Directory module
Import-Module ActiveDirectory

# Define the new root OU under which the hierarchy will be created
$newRootOU = "OU=HerePaste,DC=test,DC=com"

# Define the path to the input CSV (with samAccountName)
$inputCSV = "C:\rawData.csv"

# Generate a timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Define the output CSV file with timestamp
$outputCSV = "C:\disName_$timestamp.csv"

# Define the transcript log file with timestamp
$logFile = "C:\scriptLog_$timestamp.txt"

# Start the transcript to log the output
Start-Transcript -Path $logFile -Append

# Import the input CSV containing the samAccountName values
$users = Import-Csv -Path $inputCSV

# Create an empty array to store the results
$results = @()

# Function to ensure that the target OU hierarchy exists
function Ensure-OUExists {
    param (
        [string]$ouPath
    )
    # Check if the OU exists, if not, create it
    $ouExists = Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $ouPath } -ErrorAction SilentlyContinue
    if (-not $ouExists) {
        # Create the OU if it doesn't exist
        $ouComponents = $ouPath -split ","
        $parentOU = ($ouComponents | Select-Object -Skip 1) -join ","
        if ($parentOU) {
            Ensure-OUExists -ouPath $parentOU  # Recursively ensure parent OUs exist
        }
        New-ADOrganizationalUnit -Name ($ouComponents[0] -replace "OU=", "") -Path $parentOU
        Write-Output "Created OU: $ouPath"
    }
}

# Loop through each user in the CSV
foreach ($user in $users) {
    $samAccountName = $user.samAccountName
    
    try {
        # Search for the user in Active Directory by samAccountName
        $adUser = Get-ADUser -Filter { SamAccountName -eq $samAccountName } -Properties DistinguishedName
        
        if ($adUser) {
            # Add the samAccountName and DistinguishedName to the results array
            $results += [PSCustomObject]@{
                samAccountName    = $samAccountName
                DistinguishedName = $adUser.DistinguishedName
            }

            # Extract the original Distinguished Name (DN) from the AD user object
            $sourceDN = $adUser.DistinguishedName

            # Extract the Common Name (CN) and the current OU part
            $cn = $sourceDN.Split(',')[0]  # This gets the "CN=..." part of the DN
            $currentOUPath = $sourceDN -replace "^CN=[^,]+,", ""  # This gets the OU part of the DN

            # Construct the new OU path by appending the original hierarchy under the new root OU
            $newOUPath = $currentOUPath -replace "DC=test,DC=com$", $newRootOU  # Replace domain part with the new root OU

            # Ensure the new OU structure exists
            Ensure-OUExists -ouPath $newOUPath

            # Disable the user
            Disable-ADAccount -Identity $samAccountName -ErrorAction Stop

            # Move the user to the new OU
            $newDistinguishedName = "$cn,$newOUPath"

            try {
                Move-ADObject -Identity $sourceDN -TargetPath $newOUPath
                Write-Output "Moved user from $sourceDN to $newDistinguishedName"
            } catch {
                Write-Error "Failed to move user from $sourceDN to $newDistinguishedName. Error: $_"
            }
        } else {
            # If the user is not found, log that information
            $results += [PSCustomObject]@{
                samAccountName    = $samAccountName
                DistinguishedName = "Not Found"
            }
        }
    } catch {
        Write-Host "Error retrieving user: $samAccountName. Error: $_"
    }
}

# Export the Distinguished Name results to a new CSV file with a timestamp
$results | Export-Csv -Path $outputCSV -NoTypeInformation

# Stop the transcript to end logging
Stop-Transcript

Write-Host "Script completed. Output saved to $outputCSV and log saved to $logFile"
