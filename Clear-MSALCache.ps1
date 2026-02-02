# Clear MSAL token cache to fix authentication issues
Write-Host "`n=== Clearing MSAL Token Cache ===" -ForegroundColor Cyan
Write-Host ""

$cachePaths = @(
    "$env:LOCALAPPDATA\.msal",
    "$env:USERPROFILE\.msal",
    "$env:LOCALAPPDATA\.IdentityService",
    "$env:USERPROFILE\.IdentityService",
    "$env:LOCALAPPDATA\Microsoft\TokenBroker\Cache"
)

$clearedAny = $false

foreach ($path in $cachePaths) {
    if (Test-Path $path) {
        Write-Host "Clearing: $path" -ForegroundColor Yellow
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "  ✅ Cleared successfully" -ForegroundColor Green
            $clearedAny = $true
        } catch {
            Write-Host "  ⚠️  Could not clear (may be in use): $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Not found: $path" -ForegroundColor DarkGray
    }
}

if ($clearedAny) {
    Write-Host ""
    Write-Host "✅ Token cache cleared!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Now close ALL PowerShell windows and:" -ForegroundColor Yellow
    Write-Host "  1. Open a fresh PowerShell session" -ForegroundColor White
    Write-Host "  2. Run: Start-EntraPIM" -ForegroundColor White
    Write-Host "  3. When browser opens, make sure to select: morr@orr365.tech" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "No cache found to clear." -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host ""
