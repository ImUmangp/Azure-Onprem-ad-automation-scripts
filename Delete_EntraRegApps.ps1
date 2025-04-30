#Script will take appId as input from CSV file with Column Name AppID and delete each.

# App Registration details
$tenantId = ""
$clientId = ""
$clientSecret = ""

# Import the CSV
$csvPath = ""

# Log file path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "C:\Users\Umang.Pandey\DeleteAppsLog_$timestamp.log"

# Get token
$body = @{
    client_id     = $clientId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
$accessToken = $tokenResponse.access_token
$headers = @{ Authorization = "Bearer $accessToken" }

# Read CSV
$appList = Import-Csv -Path $csvPath

foreach ($app in $appList) {
    $appIdToDelete = $app.AppId.Trim()
    $logEntry = "Processing AppId: $appIdToDelete"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry

    # Find app object ID by appId (clientId)
    $encodedAppId = [System.Web.HttpUtility]::UrlEncode($appIdToDelete)
    $uri = "https://graph.microsoft.com/v1.0/applications?`$filter=appId eq '$encodedAppId'"

    try {
        $appInfo = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

        if ($appInfo.value.Count -eq 0) {
            $logEntry = "WARNING: AppId $appIdToDelete not found. Skipped."
            Write-Warning $logEntry
            Add-Content -Path $logFile -Value $logEntry
            continue
        }

        $objectId = $appInfo.value[0].id
        $logEntry = "Found ObjectId: $objectId. Deleting..."
        Write-Host $logEntry
        Add-Content -Path $logFile -Value $logEntry

        # Delete application
        $deleteUri = "https://graph.microsoft.com/v1.0/applications/$objectId"
        Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete

        $logEntry = "SUCCESS: AppId $appIdToDelete deleted successfully."
        Write-Host $logEntry
        Add-Content -Path $logFile -Value $logEntry
    }
    catch {
        $logEntry = "ERROR: Error processing AppId $appIdToDelete. $_"
        Write-Error $logEntry
        Add-Content -Path $logFile -Value $logEntry
    }
}
