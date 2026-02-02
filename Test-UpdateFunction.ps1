# Test the update notification function
Write-Host "Testing update notification..." -ForegroundColor Cyan
Write-Host ""

# Delete cache first
$cacheFile = Join-Path ([System.IO.Path]::GetTempPath()) "EntraPIM_UpdateCheck.json"
Remove-Item $cacheFile -ErrorAction SilentlyContinue
Write-Host "Cache deleted" -ForegroundColor Gray
Write-Host ""

# Dot-source the module to load all functions
. 'c:\Projects\Entra-PIM\Entra-PIM.psm1'

Write-Host "Calling Test-EntraPIMUpdate..." -ForegroundColor Yellow
Write-Host ""

# Call the function - this should show the notification
Test-EntraPIMUpdate

Write-Host ""
Write-Host "Test complete!" -ForegroundColor Green
