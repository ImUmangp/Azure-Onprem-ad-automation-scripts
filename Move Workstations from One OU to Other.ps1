#This script processes computer accounts in Active Directory by disabling them if they are not already disabled and,
#moving them to a specified Organizational Unit (OU) if they are not already located there.
#The script logs all actions and errors to a timestamped log file for tracking and review.


# Define variables for paths and log files
$csvFilePath = "C:\computerW\compSAM.csv" # Replace with your actual CSV file path
$logFile = "C:\computerW\LogFile_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log"
$targetOU = "OU=ComputerObject,OU=DisabledWCS,DC=test,DC=com" # Replace with your Root OU DN

# Start transcript for logging
Start-Transcript -Path $logFile -Append

# Import the CSV file
$computers = Import-Csv -Path $csvFilePath

# Loop through each computer in the CSV file
foreach ($computer in $computers) {
    $samAccountName = $computer.samAccountName

    try {
        # Get the computer object from AD
        $adComputer = Get-ADComputer -Filter {samAccountName -eq $samAccountName} -Properties DistinguishedName, Enabled

        if ($adComputer) {
            # Check if the computer account is already disabled
            if (-not $adComputer.Enabled) {
                Write-Host "Computer account is already disabled: $samAccountName" -ForegroundColor Yellow
            }
            else {
                # Disable the computer account
                Disable-ADAccount -Identity $adComputer
                Write-Host "Disabled computer: $samAccountName" -ForegroundColor Yellow
            }

            # Check if the computer is already in the target OU
            $currentOU = ($adComputer.DistinguishedName -split ",", 2)[1]
            if ($currentOU -eq $targetOU) {
                Write-Host "Computer is already in the target OU: $samAccountName" -ForegroundColor Yellow
            }
            else {
                # Move the computer to the target OU
                Move-ADObject -Identity $adComputer.DistinguishedName -TargetPath $targetOU
                Write-Host "Moved computer: $samAccountName to $targetOU" -ForegroundColor Green
            }
        }
        else {
            Write-Host "Computer not found: $samAccountName" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error processing computer: $samAccountName. Error: $_" -ForegroundColor Red
    }
}

# Stop transcript after completion
Stop-Transcript

Write-Host "Script completed. Log file saved at $logFile" -ForegroundColor Cyan
