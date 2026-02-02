# Test if Microsoft.Graph.Identity.Governance module is properly loaded
Write-Host "`n=== Testing Microsoft.Graph Module Loading ===" -ForegroundColor Cyan
Write-Host ""

# Check if module is available
$module = Get-Module -ListAvailable -Name Microsoft.Graph.Identity.Governance | Select-Object -First 1
if ($module) {
    Write-Host "Module found:" -ForegroundColor Green
    Write-Host "  Version: $($module.Version)" -ForegroundColor White
    Write-Host "  Path: $($module.ModuleBase)" -ForegroundColor Gray
} else {
    Write-Host "❌ Module not found!" -ForegroundColor Red
    exit
}

# Try to import it
Write-Host ""
Write-Host "Importing module..." -ForegroundColor Cyan
try {
    Import-Module Microsoft.Graph.Identity.Governance -Force -ErrorAction Stop
    Write-Host "  ✅ Module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Failed to import: $_" -ForegroundColor Red
    exit
}

# Check if it's loaded
$loaded = Get-Module -Name Microsoft.Graph.Identity.Governance
if ($loaded) {
    Write-Host "  ✅ Module is loaded" -ForegroundColor Green
} else {
    Write-Host "  ❌ Module not loaded after import!" -ForegroundColor Red
}

# Test if the cmdlet is available
Write-Host ""
Write-Host "Testing Get-MgRoleManagementDirectoryRoleDefinition cmdlet..." -ForegroundColor Cyan
$cmdlet = Get-Command Get-MgRoleManagementDirectoryRoleDefinition -ErrorAction SilentlyContinue
if ($cmdlet) {
    Write-Host "  ✅ Cmdlet found: $($cmdlet.Name)" -ForegroundColor Green
    Write-Host "  Module: $($cmdlet.ModuleName)" -ForegroundColor Gray
    Write-Host "  Source: $($cmdlet.Source)" -ForegroundColor Gray
} else {
    Write-Host "  ❌ Cmdlet not found!" -ForegroundColor Red
    exit
}

# Try to actually use it
Write-Host ""
Write-Host "Testing cmdlet execution..." -ForegroundColor Cyan
try {
    # Connect first
    Connect-MgGraph -Scopes 'RoleManagement.Read.Directory' -NoWelcome -ErrorAction Stop

    $roles = Get-MgRoleManagementDirectoryRoleDefinition -All -ErrorAction Stop
    Write-Host "  ✅ Successfully fetched $($roles.Count) role definitions!" -ForegroundColor Green

    if ($roles.Count -gt 0) {
        Write-Host ""
        Write-Host "Sample roles:" -ForegroundColor Yellow
        $roles | Select-Object -First 5 | ForEach-Object {
            Write-Host "  - $($_.DisplayName) ($($_.Id))" -ForegroundColor White
        }
    }
} catch {
    Write-Host "  ❌ Failed to execute: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host ""
