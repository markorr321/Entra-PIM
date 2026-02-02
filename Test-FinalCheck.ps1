# Final comprehensive test of the version check logic
Write-Host "=== Final Version Check Test ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Get current version
Write-Host "1. Current version:" -ForegroundColor Yellow
$currentModule = Get-Module -Name Entra-PIM -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1

$currentVersion = $currentModule.Version
Write-Host "   $currentVersion" -ForegroundColor Green
Write-Host ""

# Step 2: Get latest version from PowerShell Gallery
Write-Host "2. Checking PowerShell Gallery..." -ForegroundColor Yellow
$url = "https://www.powershellgallery.com/packages/Entra-PIM"
$latestVersion = $null

try {
    $null = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 5 -ErrorAction Stop
} catch {
    # When MaximumRedirection is 0, a redirect throws an exception
    # Extract version from the redirect Location header in the exception
    if ($_.Exception.Response -and $_.Exception.Response.Headers) {
        try {
            $location = $_.Exception.Response.Headers.GetValues('Location') | Select-Object -First 1
            if ($location) {
                Write-Host "   Redirect location: $location" -ForegroundColor Gray
                $versionString = Split-Path -Path $location -Leaf
                $latestVersion = [version]$versionString
                Write-Host "   Latest version: $latestVersion" -ForegroundColor Green
            }
        } catch {
            Write-Host "   Error extracting version: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""

# Step 3: Compare versions
Write-Host "3. Comparison:" -ForegroundColor Yellow
Write-Host "   Current: $currentVersion" -ForegroundColor Gray
Write-Host "   Latest:  $latestVersion" -ForegroundColor Gray
Write-Host ""

if ($currentVersion -lt $latestVersion) {
    Write-Host "   Result: UPDATE AVAILABLE!" -ForegroundColor Green
    Write-Host ""
    Write-Host "   The notification should appear!" -ForegroundColor Green
} else {
    Write-Host "   Result: Up to date (no notification)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
