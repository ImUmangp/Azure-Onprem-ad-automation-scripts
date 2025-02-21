<#
Author: Umang Pandey
Version: V1.1
Created on: 10/23/2024
Last Modified: 10/24/2024
Description: This script is developed to revoke certificates assigned to Client Machine on the basis of Certificate Template.
#>
# Path to the CSV file containing the device names
$csvFilePath = "C:\Users\Umang\Documents\certRevoke\ComputerName.csv"

# Path to the log file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFilePath = "C:\Users\Umang\Documents\certRevoke\CertificateRevocationLog_$timestamp.txt"

# Define revocation reason and other settings
$reason = "0"
$CAConfig = "ECAW16.adshared.com\adshared-ECAW16-CA"
$NetBiosName = "AD"
#$Domain= "adshared.com" No need of domain as we working through requester name "AD\$ComputerName$"

# Define the template type to REVOKE
#Machine, Workstation Authentication, OCSP Response Signing,LDAPOverSSL,CAExchange,WebServer
$certificateTemplateType = "Workstation Authentication"

# Function to log messages
function Log-Message {
    param (
        [string]$message,
        [string]$logType = "SUCCESS"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$logType] $message"
    Add-Content -Path $logFilePath -Value $logEntry

    switch ($logType) {
        "SUCCESS" { Write-Host $message -ForegroundColor Green }        
        "INFO" { Write-Host $message }
        "WARNING" { Write-Host $message -ForegroundColor Yellow }
        "ERROR" { Write-Host $message -ForegroundColor Red }
        "INFO" { Write-Host $message }
    }
}

# Log script start
Log-Message "Script execution started." -logType "INFO"

# Import the CSV file with error handling
try {
    $devices = Import-Csv -Path $csvFilePath
    if (-not $devices) {
        Log-Message "No devices found in the CSV file." -logType "WARNING"
        exit 1
    }
    Log-Message "CSV file imported successfully." -logType "INFO"
} catch {
    Log-Message "Error importing CSV file: $($_.Exception.Message)" -logType "ERROR"
    exit 1
}

# Function to get the certificate serial number from Request ID
function Get-CertificateSerialNumberFromRequestID {
    param (
        [string]$CAName,
        [int]$RequestID
    )

    $cert = certutil.exe -config $CAName -view -restrict "RequestID=$RequestID" | Out-String
    $serialNumber = ($cert -split "\r?\n" | Where-Object { $_ -match "^  Serial Number:" }) -replace 'Serial Number:', '' -replace '[\s"]', ''

    if ($serialNumber) {
        Log-Message "Serial Number for Request ID $RequestID is $serialNumber." -logType "INFO"
    } else {
        Log-Message "Serial number not found for Request ID $RequestID." -logType "ERROR"
    }

    return $serialNumber
}

# Function to get the certificate template name from Request ID
function Get-CertificateTemplateName {
    param (
        [string]$CAName,    # The name of the Certificate Authority (CA)
        [int]$RequestID     # The request ID of the certificate
    )

    # Run certutil command to get certificate details for a specific request ID
    $certutilOutput = certutil -view -restrict "RequestID=$requestID" -out RequestID,CertificateTemplate
    $lines = $certutilOutput -split "`n"
    $templateName = $null

    # Loop through each line to find the Certificate Template line
    foreach ($line in $lines) {
        if ($line -match "Certificate Template:\s*(\S+)\s*(.*)") {
            $templateName = $matches[1].Trim('"')
            $description = $matches[2].Trim()

            # Check if the template name includes an OID and a description
            if ($templateName -match "^\d+\.\d+\.\d+\.\d+\.\d+" -and $description -match "Workstation Authentication") {
                $templateName = "Workstation Authentication"
            }
            elseif ($templateName -match "^\d+\.\d+\.\d+\.\d+\.\d+" -and $description -match "OCSP Response Signing") {
                $templateName = "OCSP Response Signing"
            }
            elseif ($templateName -match "^\d+\.\d+\.\d+\.\d+\.\d+" -and $description -match "LDAPOverSSL") {
                $templateName = "LDAPOverSSL"
            }
            break
        }
    }

    # Log and return the template name
    if ($templateName) {
        Log-Message "Certificate template for Request ID $requestID is: $templateName." -logType "INFO"
    } else {
        Log-Message "No certificate template found for Request ID $requestID." -logType "ERROR"
    }

    return $templateName
}

# Function to revoke the certificate by template
function Revoke-CertificateByTemplate {
    param (
        [string]$templateName,
        [int]$requestID,
        [string]$serialNumber
    )

    if ($templateName -eq $certificateTemplateType) {
        Log-Message "Revoking certificate with Request ID: $requestID." -logType "WARNING"
        try {
            # Run certutil revoke command (uncomment the actual command when ready for production)
            
            #certutil -config $CAConfig -revoke $serialNumber $reason
            if ($LASTEXITCODE -eq 0) {
                Log-Message "Certificate with Request ID $requestID has been revoked." -logType "SUCCESS"
            } else {
                Log-Message "Failed to revoke certificate with Request ID $requestID." -logType "ERROR"
            }
        } catch {
            Log-Message "Error revoking certificate with Request ID $requestID $($_.Exception.Message)" -logType "ERROR"
        }
    } else {
        Log-Message "Template '$templateName' does not match required template '$certificateTemplateType'. No action taken." -logType "WARNING"
    }
}

# Main loop to process each device
foreach ($device in $devices) {
    $CertSubjectName = $device.ComputerName
    #$ComputerName = "$CertSubjectName.$Domain"
     #$ComputerName = "adshared-ECAW16-CA-Xchg"
     
     $ComputerName = "$NetBiosName\$CertSubjectName$"
    Write-Host "----------------------------------------------------"
    Log-Message "Searching for certificates issued to: $ComputerName." -logType "INFO"
    Write-Host "----------------------------------------------------"
    # Gather all RequestIDs for this ComputerName
    $requestIDs = @()

    try {
        $certUtilQuery = & certutil -config "$CAConfig" -view -out "RequestID" -restrict "Requester Name=$ComputerName,Disposition=20" 2>&1
    } catch {
        Log-Message "Error executing certutil for $ComputerName $($_.Exception.Message)" -logType "ERROR"
        continue
    }

    # Extract RequestIDs from certutil output
    foreach ($line in $certUtilQuery) {
        if ($line -match "Issued Request ID:\s*0x([A-Fa-f0-9]+)") {
            $requestID = [convert]::ToInt32($matches[1], 16)
            $requestIDs += $requestID
        }
    }

    if ($requestIDs.Count -eq 0) {
        Log-Message "No certificates found for $ComputerName." -logType "WARNING"
    } else {
        # Process each RequestID
        foreach ($requestID in $requestIDs) {
            Log-Message "Processing Request ID $requestID for $ComputerName." -logType "INFO"
            $serialNumber = Get-CertificateSerialNumberFromRequestID -CAName $CAConfig -RequestID $requestID
            $templateName = Get-CertificateTemplateName -CAName $CAConfig -RequestID $requestID

            if ($serialNumber) {
                Revoke-CertificateByTemplate -templateName $templateName -requestID $requestID -serialNumber $serialNumber
            } else {
                Log-Message "Could not retrieve serial number for Request ID $requestID." -logType "ERROR"
            }
        }
    }
}

# Log script end
Log-Message "Script execution completed." -logType "INFO"
Write-Host "Log file saved at $logFilePath."
