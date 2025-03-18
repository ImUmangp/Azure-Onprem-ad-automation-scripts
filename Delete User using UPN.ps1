#This Scripts deletes USER from AD using its UPN 
# Define the path to your CSV file and log file
$csvPath = "C:\upnDelete.csv"
$logPath = "C:\logFile.txt"

# Import the CSV file
$users = Import-Csv -Path $csvPath

# Create or clear the log file
Clear-Content -Path $logPath -ErrorAction SilentlyContinue
Add-Content -Path $logPath -Value "Timestamp,UserPrincipalName,Status,ErrorMessage"

# Loop through each user in the CSV file
foreach ($user in $users) {
    # Get the User Principal Name (UPN) from the CSV
    $upn = $user.UserPrincipalName

    try {
        # Attempt to find the user in Active Directory by UPN
        $adUser = Get-ADUser -Filter { UserPrincipalName -eq $upn } -ErrorAction SilentlyContinue

        # Check if the user was found
        if ($adUser -eq $null) {
            # Log user not found case
            $logEntry = "{0},{1},Failed,User not found in that DC" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $upn
            Add-Content -Path $logPath -Value $logEntry
        } else {
            # If user is found, attempt to delete the user
            Remove-ADUser -Identity $adUser.DistinguishedName -Confirm:$false -ErrorAction Stop

            # Log success
            $logEntry = "{0},{1},Success," -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $upn
            Add-Content -Path $logPath -Value $logEntry
        }

    } catch {
        # If there is an error, capture the error message
        $errorMessage = $_.Exception.Message

        # Log failure
        $logEntry = "{0},{1},Failed,{2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $upn, $errorMessage
        Add-Content -Path $logPath -Value $logEntry
    }
}

Write-Host "User deletion process completed. Check the log file at $logPath for details."
