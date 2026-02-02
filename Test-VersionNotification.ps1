# Test the version update notification display
# This simulates what users will see when an update is available

Write-Host "`n=== Testing Entra-PIM Update Notification ===" -ForegroundColor Cyan
Write-Host ""

# Load the module functions into current scope
$moduleContent = Get-Content 'c:\Projects\Entra-PIM\Entra-PIM.psm1' -Raw

# Extract and define the Show-UpdateNotification function
$functionPattern = '(?s)function Show-UpdateNotification \{.*?\n\}'
if ($moduleContent -match $functionPattern) {
    Invoke-Expression $matches[0]

    Write-Host "Simulating notification (as if you had 2.0.0 and 2.1.0 is available):" -ForegroundColor Yellow
    Write-Host ""

    # Call the notification function
    Show-UpdateNotification -CurrentVersion "2.0.0" -LatestVersion "2.1.0"

    Write-Host "✓ Notification display test complete!" -ForegroundColor Green
} else {
    Write-Host "Could not extract function" -ForegroundColor Red
}
