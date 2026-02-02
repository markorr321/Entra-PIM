$cache = Join-Path ([System.IO.Path]::GetTempPath()) 'EntraPIM_UpdateCheck.json'
if (Test-Path $cache) {
    Write-Host "Cache file found at: $cache" -ForegroundColor Green
    Write-Host ""
    Get-Content $cache | ConvertFrom-Json | Format-List
} else {
    Write-Host "Cache file not found" -ForegroundColor Red
}
