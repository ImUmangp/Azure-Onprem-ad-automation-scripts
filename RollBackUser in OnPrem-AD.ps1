# Import Active Directory module
Import-Module ActiveDirectory

# Define the path to the input CSV that has the samAccountName and original DistinguishedName
$inputCSV = "C:\userRollBack\rollBack.csv"

# Generate a timestamp for logging purposes
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Define the transcript log file with timestamp
$logFile = "C:\userRollBack\rollbackScriptLog_$timestamp.txt"

# Start the transcript to log the output
Start-Transcript -Path $logFile -Append

# Import the CSV containing the samAccountName and original DistinguishedName
$users = Import-Csv -Path $inputCSV

# Loop through each user in the CSV
foreach ($user in $users) {
    $samAccountName = $user.samAccountName
    $originalDN = $user.DistinguishedName

    try {
        # Search for the user in Active Directory by samAccountName
        $adUser = Get-ADUser -Filter { SamAccountName -eq $samAccountName } -Properties DistinguishedName
        
        if ($adUser) {
            # Extract the current Distinguished Name (DN) from the AD user object
            $currentDN = $adUser.DistinguishedName
            
            # Re-enable the user
            Enable-ADAccount -Identity $samAccountName -ErrorAction Stop
            Write-Output "User $samAccountName has been enabled."
            
            # Move the user back to the original OU
            try {
                Move-ADObject -Identity $currentDN -TargetPath $originalDN -ErrorAction Stop
                Write-Output "User $samAccountName moved back to $originalDN."
            } catch {
                Write-Error "Failed to move user $samAccountName back to $originalDN. Error: $_"
            }
        } else {
            Write-Host "User $samAccountName not found in AD."
        }
    } catch {
        Write-Host "Error processing user $samAccountName. Error: $_"
    }
}

# Stop the transcript to end logging
Stop-Transcript

Write-Host "Rollback completed. Log saved to $logFile"
