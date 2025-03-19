# Import Active Directory Module
Import-Module ActiveDirectory

# Path to CSV file containing user details
$csvPath = "C:\DummyUsers.csv"

# Import CSV and loop through each entry
Import-Csv -Path $csvPath | ForEach-Object {
    # Define user details
    $FirstName = $_.FirstName
    $LastName = $_.LastName
    $SamAccountName = $_.SamAccountName
    $UserPrincipalName = $_.UserPrincipalName
    $OU = $_.OU
    $Password = $_.Password
    $Name = "$FirstName $LastName"  # Combine FirstName and LastName for the 'Name' parameter

    # Create a new user in AD
    New-ADUser -Name $Name `
               -GivenName $FirstName `
               -Surname $LastName `
               -SamAccountName $SamAccountName `
               -UserPrincipalName $UserPrincipalName `
               -Path $OU `
               -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
               -Enabled $true `
               -ChangePasswordAtLogon $false

    Write-Host "User $SamAccountName created successfully in $OU"
}

Write-Host "All users imported successfully."
