# Compare environment settings between machines
Write-Host "`n=== Environment Comparison Diagnostic ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "POWERSHELL VERSION" -ForegroundColor Yellow
Write-Host "  Version: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "  Edition: $($PSVersionTable.PSEdition)" -ForegroundColor White
Write-Host "  OS: $($PSVersionTable.OS)" -ForegroundColor White
Write-Host ""

Write-Host "REGIONAL SETTINGS" -ForegroundColor Yellow
$culture = [System.Globalization.CultureInfo]::CurrentCulture
Write-Host "  Culture: $($culture.Name)" -ForegroundColor White
Write-Host "  Date Format: $($culture.DateTimeFormat.ShortDatePattern)" -ForegroundColor White
Write-Host "  Time Format: $($culture.DateTimeFormat.ShortTimePattern)" -ForegroundColor White
Write-Host "  Sample Date: $((Get-Date).ToString())" -ForegroundColor White
Write-Host ""

Write-Host "MICROSOFT.GRAPH MODULES" -ForegroundColor Yellow
$graphModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Identity.DirectoryManagement",
    "Microsoft.Graph.Identity.Governance"
)

foreach ($module in $graphModules) {
    $installed = Get-Module -ListAvailable -Name $module | Select-Object -First 1
    if ($installed) {
        Write-Host "  $module : $($installed.Version)" -ForegroundColor White
    } else {
        Write-Host "  $module : NOT INSTALLED" -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "ENTRA-PIM MODULE" -ForegroundColor Yellow
$entraPIM = Get-Module -ListAvailable -Name Entra-PIM | Sort-Object Version -Descending | Select-Object -First 1
if ($entraPIM) {
    Write-Host "  Version: $($entraPIM.Version)" -ForegroundColor White
    Write-Host "  Path: $($entraPIM.ModuleBase)" -ForegroundColor Gray
    Write-Host "  Scope: $(if($entraPIM.ModuleBase -like '*Program Files*'){'System'}else{'User'})" -ForegroundColor White
} else {
    Write-Host "  NOT INSTALLED" -ForegroundColor Red
}
Write-Host ""

Write-Host "ENVIRONMENT VARIABLES" -ForegroundColor Yellow
Write-Host "  ENTRAPIM_CLIENTID: $([System.Environment]::GetEnvironmentVariable('ENTRAPIM_CLIENTID', 'User'))" -ForegroundColor White
Write-Host "  ENTRAPIM_TENANTID: $([System.Environment]::GetEnvironmentVariable('ENTRAPIM_TENANTID', 'User'))" -ForegroundColor White
Write-Host "  ENTRAPIM_DISABLE_UPDATE_CHECK: $([System.Environment]::GetEnvironmentVariable('ENTRAPIM_DISABLE_UPDATE_CHECK', 'User'))" -ForegroundColor White
Write-Host ""

Write-Host "DATETIME PARSING TEST" -ForegroundColor Yellow
$testDate = "02/02/2026 21:46:45"
try {
    $parsed = [DateTime]::Parse($testDate)
    Write-Host "  Input: $testDate" -ForegroundColor White
    Write-Host "  Parsed as: $parsed" -ForegroundColor White
    Write-Host "  Year: $($parsed.Year), Month: $($parsed.Month), Day: $($parsed.Day)" -ForegroundColor Gray
} catch {
    Write-Host "  ❌ Failed to parse: $testDate" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== Copy this output to compare with working machine ===" -ForegroundColor Cyan
Write-Host ""
