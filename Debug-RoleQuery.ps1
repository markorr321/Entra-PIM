# Deep diagnostic script to debug role retrieval
Write-Host "`n=== Entra PIM Role Query Diagnostics ===" -ForegroundColor Cyan
Write-Host ""

# First check authentication
try {
    $context = Get-MgContext -ErrorAction Stop
    Write-Host "✅ Connected to Microsoft Graph" -ForegroundColor Green
    Write-Host "   Account: $($context.Account)" -ForegroundColor White
    Write-Host "   TenantId: $($context.TenantId)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "❌ Not connected to Microsoft Graph. Run this first:" -ForegroundColor Red
    Write-Host "   Connect-MgGraph -Scopes 'RoleAssignmentSchedule.ReadWrite.Directory','RoleEligibilitySchedule.ReadWrite.Directory','RoleManagement.Read.Directory','RoleManagementPolicy.Read.Directory'" -ForegroundColor Yellow
    exit
}

# Get current user
Write-Host "Getting current user information..." -ForegroundColor Cyan
try {
    $me = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/me" -ErrorAction Stop
    $userId = $me.id
    Write-Host "✅ Current User:" -ForegroundColor Green
    Write-Host "   DisplayName: $($me.displayName)" -ForegroundColor White
    Write-Host "   UPN: $($me.userPrincipalName)" -ForegroundColor White
    Write-Host "   User ID: $userId" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ Failed to get current user: $_" -ForegroundColor Red
    exit
}

# Query eligible role assignments (the exact same query the module uses)
Write-Host "Querying eligible role assignments..." -ForegroundColor Cyan
try {
    $uri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilityScheduleInstances?`$filter=principalId eq '$userId'&`$select=roleDefinitionId,principalId,directoryScopeId"
    Write-Host "   URI: $uri" -ForegroundColor Gray
    Write-Host ""

    $eligibilityResponse = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
    $eligibilitySchedules = if ($eligibilityResponse -and $eligibilityResponse.value) { $eligibilityResponse.value } else { @() }

    Write-Host "✅ Query successful!" -ForegroundColor Green
    Write-Host "   Found $($eligibilitySchedules.Count) eligible role(s)" -ForegroundColor White
    Write-Host ""

    if ($eligibilitySchedules.Count -eq 0) {
        Write-Host "⚠️  PROBLEM IDENTIFIED: The Graph API returned 0 eligible roles" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This means one of the following:" -ForegroundColor Yellow
        Write-Host "  1. You're authenticated as the wrong user" -ForegroundColor White
        Write-Host "  2. Your account genuinely has no PIM eligible roles in this tenant" -ForegroundColor White
        Write-Host "  3. There's a permissions/consent issue with the Graph API" -ForegroundColor White
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  • Verify in Azure Portal that $($me.userPrincipalName) has PIM eligible roles" -ForegroundColor White
        Write-Host "  • Go to: https://portal.azure.com → Entra ID → Roles and administrators → My roles" -ForegroundColor White
        Write-Host "  • Check the 'Eligible assignments' tab" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "✅ Roles found! Details:" -ForegroundColor Green
        foreach ($schedule in $eligibilitySchedules) {
            Write-Host "   Role Definition ID: $($schedule.roleDefinitionId)" -ForegroundColor White
            Write-Host "   Directory Scope ID: $($schedule.directoryScopeId)" -ForegroundColor Gray

            # Try to get role name
            try {
                $roleDef = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions/$($schedule.roleDefinitionId)" -ErrorAction Stop
                Write-Host "   Role Name: $($roleDef.displayName)" -ForegroundColor Cyan
            } catch {
                Write-Host "   (Could not retrieve role name)" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    }
} catch {
    Write-Host "❌ Query failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    if ($_ -match "Forbidden|403") {
        Write-Host "⚠️  This looks like a permissions issue." -ForegroundColor Yellow
        Write-Host "   The app/user doesn't have the required Graph API permissions." -ForegroundColor White
        Write-Host ""
        Write-Host "Try reconnecting with explicit scopes:" -ForegroundColor Cyan
        Write-Host "   Disconnect-MgGraph" -ForegroundColor White
        Write-Host "   Connect-MgGraph -Scopes 'RoleEligibilitySchedule.Read.Directory','RoleManagement.Read.Directory'" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "=== Diagnostic Complete ===" -ForegroundColor Cyan
Write-Host ""
