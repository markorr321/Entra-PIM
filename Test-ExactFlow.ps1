# Test the EXACT code flow that Start-EntraPIM uses
Write-Host "`n=== Testing Exact Start-EntraPIM Flow ===" -ForegroundColor Cyan
Write-Host ""

# Get current user
try {
    $me = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/me" -ErrorAction Stop
    $CurrentUserId = $me.id
    Write-Host "User ID: $CurrentUserId" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ Not connected. Run Connect-MgGraph first" -ForegroundColor Red
    exit
}

# Import the Get-EligibleRolesOptimized function from the module
Write-Host "Loading Entra-PIM module functions..." -ForegroundColor Cyan
$modulePath = (Get-Module -ListAvailable -Name Entra-PIM | Select-Object -First 1).ModuleBase
$scriptPath = Join-Path $modulePath "Entra-PIM.ps1"

if (Test-Path $scriptPath) {
    Write-Host "  Script path: $scriptPath" -ForegroundColor Gray

    # Dot-source the script to load all functions
    . $scriptPath -ClientId "test" -TenantId "test" -ErrorAction SilentlyContinue 2>$null

    Write-Host "  ✅ Functions loaded" -ForegroundColor Green
} else {
    Write-Host "  ❌ Cannot find Entra-PIM.ps1" -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "Calling Get-EligibleRolesOptimized..." -ForegroundColor Cyan
Write-Host ""

try {
    # Initialize the role definition cache first (like the real code does)
    if (Get-Command Initialize-RoleDefinitionCache -ErrorAction SilentlyContinue) {
        Initialize-RoleDefinitionCache
    }

    # Call the function exactly as Start-EntraPIM does
    $validRoles = Get-EligibleRolesOptimized -CurrentUserId $CurrentUserId

    Write-Host ""
    Write-Host "Results:" -ForegroundColor Yellow
    Write-Host "  Type: $($validRoles.GetType().FullName)" -ForegroundColor Gray
    Write-Host "  Is Null: $($null -eq $validRoles)" -ForegroundColor Gray
    Write-Host "  Count: $($validRoles.Count)" -ForegroundColor White
    Write-Host "  Count -eq 0: $($validRoles.Count -eq 0)" -ForegroundColor $(if($validRoles.Count -eq 0){'Red'}else{'Green'})
    Write-Host ""

    if ($validRoles.Count -gt 0) {
        Write-Host "✅ SUCCESS: $($validRoles.Count) roles returned" -ForegroundColor Green
        Write-Host ""
        Write-Host "Roles:" -ForegroundColor Cyan
        foreach ($role in $validRoles) {
            Write-Host "  - $($role.RoleDefinition.DisplayName)" -ForegroundColor White
        }
    } else {
        Write-Host "❌ PROBLEM: Function returned 0 roles" -ForegroundColor Red
        Write-Host ""
        Write-Host "This matches the bug you're seeing in Start-EntraPIM" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error calling function: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host ""
