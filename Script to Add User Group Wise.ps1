# Script to Add User Group Wise
# Import Active Directory Module
 Import-Module ActiveDirectory

 # Path to CSV file containing user and group details
 $csvPath = "C:\letsFinal.csv"

 # Define the base path for groups in the GroupManagement OU
 $GroupOUPath = "OU=GroupManagement,DC=umang,DC=com"

 # Import CSV and loop through each entry
 Import-Csv -Path $csvPath | ForEach-Object {
     # Define user details
     $FirstName = $_.FirstName
     $LastName = $_.LastName
     $SamAccountName = $_.SamAccountName
     $UserPrincipalName = $_.UserPrincipalName
     $OU = $_.OU
     $Password = $_.Password
     $GroupName = $_.GroupName
     


     # Ensure that the GroupName is not null or empty
     if ([string]::IsNullOrWhiteSpace($GroupName)) {
         Write-Host "Error: Group name is null or empty for user ${SamAccountName}."
         return
     }

     # Ensure the group exists in the GroupManagement OU; if not, create it
     try {
         $group = Get-ADGroup -Filter "Name -eq '$GroupName'" -SearchBase $GroupOUPath -ErrorAction SilentlyContinue
         if (-not $group) {
             New-ADGroup -Name $GroupName -GroupScope Global -GroupCategory Security -Path $GroupOUPath
             Write-Host "Group $GroupName created successfully in $GroupOUPath."
         }
     } catch {
         Write-Host ("Error creating group ${GroupName}: {0}" -f $_.Exception.Message)
         return
     }
       $ppassword = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force
     # Check if the user already exists
     $existingUser = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue
     if (-not $existingUser) {
         # Create a new user in their specified OU (not the Group OU)
         try {
             New-ADUser -Name "$FirstName $LastName" `
                        -GivenName $FirstName `
                        -Surname $LastName `
                        -SamAccountName $SamAccountName `
                        -UserPrincipalName $UserPrincipalName `
                        -Path $OU `  # Ensure the user is created in their designated OU
                        #-AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
                         -AccountPassword $ppassword `
                        #-AccountPassword $securePassword `
                         #-PasswordNeverExpires $true `
                        -Enabled $true `
                        -ChangePasswordAtLogon $false

             Write-Host "User $SamAccountName created successfully in $OU."
         } catch {
             Write-Host ("Error creating user ${SamAccountName}: {0}" -f $_.Exception.Message)
             return
         }
     } else {
         Write-Host "User $SamAccountName already exists."
     }

     # Ensure the group exists before adding the user
     $group = Get-ADGroup -Filter "Name -eq '$GroupName'" -SearchBase $GroupOUPath -ErrorAction SilentlyContinue
     if (-not $group) {
         Write-Host "Error: The specified group ${GroupName} does not exist."
         return
     }

     # Add the user to the specified group (group is in GroupManagement OU)
     try {
         Add-ADGroupMember -Identity $GroupName -Members $SamAccountName
         Write-Host "User $SamAccountName added to group $GroupName."
     } catch {
         Write-Host ("Error adding user ${SamAccountName} to group ${GroupName}: {0}" -f $_.Exception.Message)
     }
 }

 Write-Host "All users processed and added to their respective groups successfully."
