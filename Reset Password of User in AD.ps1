#This Script takesnusername from CSV file as input and reset the password of all username. 
# Define the input CSV file and log file paths
$csvFilePath = "C:\passwordReset\userForPassword.csv"
$logFilePath = "C:\passwordReset\PasswordResetLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Start transcript for logging (this will log all output automatically)
Start-Transcript -Path $logFilePath

# Import the CSV file
$users = Import-Csv -Path $csvFilePath

# Process each user from the CSV
foreach ($user in $users) {
    $samAccountName = $user.samAccountName
    $newPassword = $user.Password

    try {
        # Try to find the user account in Active Directory
        $adUser = Get-ADUser -Filter {SamAccountName -eq $samAccountName} -ErrorAction Stop

        # Check if the user was found
        if ($null -ne $adUser) {
            # Reset the password
            Set-ADAccountPassword -Identity $adUser -NewPassword (ConvertTo-SecureString $newPassword -AsPlainText -Force) -Reset

            # Enable "User must change password at next logon"
            Set-ADUser -Identity $adUser -PasswordNeverExpires $false -ChangePasswordAtLogon $true

            # Log success message to console (will be captured by transcript)
            Write-Host "Password for user '$samAccountName' has been successfully reset." -ForegroundColor Green
        } else {
            # If user is not found, log an appropriate message
            Write-Host "User '$samAccountName' not found in Active Directory." -ForegroundColor Yellow
        }
    } catch {
        # Handle any other error
        Write-Host "Failed to reset password for user '$samAccountName'. Error: $_" -ForegroundColor Red
    }
}

# Stop transcript
Stop-Transcript
