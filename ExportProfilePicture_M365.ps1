# App Registration details
$tenantId = ""
$clientId = ""
$clientSecret = ""

$authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$graphUrl = "https://graph.microsoft.com/v1.0"
$outputFolder = "C:\M365Photos"

# Create output directory if not exists
if (-Not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# Get OAuth token
$tokenBody = @{
    grant_type    = "client_credentials"
    scope         = "https://graph.microsoft.com/.default"
    client_id     = $clientId
    client_secret = $clientSecret
}

$tokenResponse = Invoke-RestMethod -Method Post -Uri $authUrl -ContentType "application/x-www-form-urlencoded" -Body $tokenBody
$accessToken = $tokenResponse.access_token

# Headers for Graph API
$headers = @{
    Authorization = "Bearer $accessToken"
}

# Function to download photo if available and valid
function Download-UserPhoto {
    param (
        [string]$userId,
        [string]$userPrincipalName
    )

    $photoUri = "$graphUrl/users/$userId/photo/`$value"
    $outputPath = Join-Path -Path $outputFolder -ChildPath "$userPrincipalName.jpg"

    try {
        $photoResponse = Invoke-WebRequest -Headers $headers -Uri $photoUri -Method Get -ErrorAction Stop

        if ($photoResponse.StatusCode -eq 200 -and $photoResponse.Headers["Content-Type"] -like "image/*") {
            [System.IO.File]::WriteAllBytes($outputPath, $photoResponse.Content)
            Write-Host "✅ Downloaded photo for $userPrincipalName"
        } else {
            Write-Warning "⚠️ Unexpected content for $userPrincipalName — Skipped"
        }
    } catch {
        Write-Warning "❌ No photo or failed request for $userPrincipalName"
    }
}

# Paging through all users (Graph returns paged data)
$uri = "$graphUrl/users?$top=999"

do {
    $userResponse = Invoke-RestMethod -Headers $headers -Uri $uri -Method Get

    foreach ($user in $userResponse.value) {
        Download-UserPhoto -userId $user.id -userPrincipalName $user.userPrincipalName
    }

    $uri = $userResponse.'@odata.nextLink'

} while ($uri)
