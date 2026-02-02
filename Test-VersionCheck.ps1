# Test the version check logic
Write-Host "Testing version check logic..." -ForegroundColor Cyan
Write-Host ""

# Test 1: Get current version
Write-Host "1. Getting current module version:" -ForegroundColor Yellow
$currentModule = Get-Module -Name Entra-PIM -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($currentModule) {
    Write-Host "   Current version: $($currentModule.Version)" -ForegroundColor Green
} else {
    Write-Host "   ERROR: Module not found!" -ForegroundColor Red
    exit
}

# Test 2: Check PowerShell Gallery
Write-Host ""
Write-Host "2. Checking PowerShell Gallery:" -ForegroundColor Yellow

try {
    $url = "https://www.powershellgallery.com/packages/Entra-PIM"
    Write-Host "   Requesting: $url" -ForegroundColor Gray

    try {
        $null = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 5 -ErrorAction Stop
    } catch {
        Write-Host "   Exception Type: $($_.Exception.GetType().Name)" -ForegroundColor Yellow
        Write-Host "   Exception Message: $($_.Exception.Message)" -ForegroundColor Yellow

        # When MaximumRedirection is 0, a redirect throws an exception
        # Extract version from the redirect Location header in the exception
        if ($_.Exception.Response -and $_.Exception.Response.Headers -and $_.Exception.Response.Headers['Location']) {
            $location = $_.Exception.Response.Headers['Location'].ToString()
            Write-Host "   Location Header: $location" -ForegroundColor Gray
            $versionString = Split-Path -Path $location -Leaf
            $latestVersion = [version]$versionString
            Write-Host "   Latest version (from exception): $latestVersion" -ForegroundColor Green
        } else {
            Write-Host "   ERROR: Could not extract location from exception" -ForegroundColor Red
        }
    }

} catch {
    Write-Host "   Outer Exception: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Version comparison
Write-Host ""
Write-Host "3. Version comparison:" -ForegroundColor Yellow
$currentVersion = $currentModule.Version

if ($latestVersion) {
    Write-Host "   Current: $currentVersion" -ForegroundColor Gray
    Write-Host "   Latest:  $latestVersion" -ForegroundColor Gray

    if ($currentVersion -lt $latestVersion) {
        Write-Host "   Result: UPDATE AVAILABLE!" -ForegroundColor Green
    } else {
        Write-Host "   Result: Up to date" -ForegroundColor Gray
    }
} else {
    Write-Host "   ERROR: Could not determine latest version" -ForegroundColor Red
}
