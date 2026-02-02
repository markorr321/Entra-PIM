# Diagnostic script to check Microsoft Graph authentication
Write-Host "`n=== Microsoft Graph Authentication Diagnostics ===" -ForegroundColor Cyan
Write-Host ""

# Check if already connected
try {
    $context = Get-MgContext -ErrorAction SilentlyContinue
    if ($context) {
        Write-Host "Current Microsoft Graph Context:" -ForegroundColor Yellow
        Write-Host "  Account: $($context.Account)" -ForegroundColor White
        Write-Host "  Scopes: $($context.Scopes -join ', ')" -ForegroundColor Gray
        Write-Host "  TenantId: $($context.TenantId)" -ForegroundColor Gray
        Write-Host ""

        # Try to get current user details
        try {
            $me = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/me" -ErrorAction Stop
            Write-Host "Authenticated User Details:" -ForegroundColor Yellow
            Write-Host "  DisplayName: $($me.displayName)" -ForegroundColor White
            Write-Host "  UserPrincipalName: $($me.userPrincipalName)" -ForegroundColor White
            Write-Host "  User ID: $($me.id)" -ForegroundColor White
            Write-Host ""

            Write-Host "⚠️  If this is NOT your expected account, disconnect and reconnect." -ForegroundColor Red
        } catch {
            Write-Host "❌ Failed to get user details: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Not currently connected to Microsoft Graph" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error checking Graph context: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "To fix authentication issues:" -ForegroundColor Cyan
Write-Host "  1. Disconnect-MgGraph" -ForegroundColor White
Write-Host "  2. Clear cached tokens (instructions below)" -ForegroundColor White
Write-Host "  3. Run Start-EntraPIM again" -ForegroundColor White
Write-Host ""

Write-Host "Token Cache Locations:" -ForegroundColor Yellow
Write-Host "  Windows: %LOCALAPPDATA%\.IdentityService" -ForegroundColor Gray
Write-Host "  Windows: %USERPROFILE%\.azure" -ForegroundColor Gray
Write-Host "  macOS/Linux: ~/.IdentityService" -ForegroundColor Gray
Write-Host ""
