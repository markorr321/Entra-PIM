# Diagnostic script to understand why notification isn't appearing
Write-Host "=== Diagnostic Check ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check what version is loaded
Write-Host "1. Currently loaded module:" -ForegroundColor Yellow
$loadedModule = Get-Module Entra-PIM
if ($loadedModule) {
    Write-Host "   Version: $($loadedModule.Version)" -ForegroundColor Green
    Write-Host "   Path: $($loadedModule.Path)" -ForegroundColor Gray
} else {
    Write-Host "   No module loaded" -ForegroundColor Red
}
Write-Host ""

# 2. Check what Get-Module -ListAvailable returns (what the function will see)
Write-Host "2. What Test-EntraPIMUpdate will see:" -ForegroundColor Yellow
$currentModule = Get-Module -Name Entra-PIM -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($currentModule) {
    Write-Host "   Version: $($currentModule.Version)" -ForegroundColor Green
    Write-Host "   Path: $($currentModule.Path)" -ForegroundColor Gray
} else {
    Write-Host "   No module found" -ForegroundColor Red
}
Write-Host ""

# 3. Check cache
Write-Host "3. Cache contents:" -ForegroundColor Yellow
$cacheFile = Join-Path ([System.IO.Path]::GetTempPath()) "EntraPIM_UpdateCheck.json"
if (Test-Path $cacheFile) {
    $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
    Write-Host "   LastCheckTime: $($cache.LastCheckTime)" -ForegroundColor Gray
    Write-Host "   CurrentVersion: $($cache.CurrentVersion)" -ForegroundColor Gray
    Write-Host "   LatestVersion: $($cache.LatestVersion)" -ForegroundColor Gray

    $lastCheck = [DateTime]::Parse($cache.LastCheckTime)
    $hoursSinceCheck = ((Get-Date) - $lastCheck).TotalHours
    Write-Host "   Hours since check: $([Math]::Round($hoursSinceCheck, 2))" -ForegroundColor Gray

    if ($hoursSinceCheck -lt 24) {
        Write-Host "   Cache is VALID (< 24 hours)" -ForegroundColor Yellow
    } else {
        Write-Host "   Cache is STALE (> 24 hours)" -ForegroundColor Yellow
    }
} else {
    Write-Host "   No cache file found" -ForegroundColor Gray
}
Write-Host ""

# 4. Version comparison
Write-Host "4. Will notification appear?" -ForegroundColor Yellow
if ($currentModule -and $cacheFile -and (Test-Path $cacheFile)) {
    $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
    $currentVer = $currentModule.Version
    $latestVer = [version]$cache.LatestVersion

    Write-Host "   Comparing: $currentVer < $latestVer" -ForegroundColor Gray

    if ($currentVer -lt $latestVer) {
        Write-Host "   YES - Notification SHOULD appear!" -ForegroundColor Green
    } else {
        Write-Host "   NO - Versions are equal or current is newer" -ForegroundColor Red
        Write-Host "   This is why the notification isn't appearing!" -ForegroundColor Red
    }
} else {
    Write-Host "   Cannot determine" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== End Diagnostic ===" -ForegroundColor Cyan
