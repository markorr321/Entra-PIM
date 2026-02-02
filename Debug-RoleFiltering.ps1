# Debug script to see exactly how roles are being filtered
Write-Host "`n=== Debugging Role Filtering Logic ===" -ForegroundColor Cyan
Write-Host ""

# Get current user
try {
    $me = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/me" -ErrorAction Stop
    $userId = $me.id
    Write-Host "User ID: $userId" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ Not connected. Run Connect-MgGraph first" -ForegroundColor Red
    exit
}

# Query eligible roles (same as the module does)
Write-Host "1. Querying ELIGIBLE roles..." -ForegroundColor Cyan
$eligibilityResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilityScheduleInstances?`$filter=principalId eq '$userId'&`$select=roleDefinitionId,principalId,directoryScopeId" -ErrorAction Stop
$eligibilitySchedules = if ($eligibilityResponse -and $eligibilityResponse.value) { $eligibilityResponse.value } else { @() }
Write-Host "   Found $($eligibilitySchedules.Count) eligible roles" -ForegroundColor Green
Write-Host ""

# Query active roles (same as the module does)
Write-Host "2. Querying ACTIVE roles..." -ForegroundColor Cyan
try {
    $activeResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances?`$filter=principalId eq '$userId' and assignmentType eq 'Activated'&`$select=roleDefinitionId,endDateTime" -ErrorAction Stop
    $activatedAssignments = if ($activeResponse -and $activeResponse.value) { $activeResponse.value } else { @() }
} catch {
    $activatedAssignments = @()
}

Write-Host "   Found $($activatedAssignments.Count) active assignments" -ForegroundColor White

# Process active roles (same logic as module)
$activeRoleIds = @()
if ($activatedAssignments -and $activatedAssignments.Count -gt 0) {
    $currentTime = Get-Date
    Write-Host "   Current time: $currentTime" -ForegroundColor Gray

    foreach ($assignment in $activatedAssignments) {
        Write-Host "   Assignment:" -ForegroundColor DarkGray
        Write-Host "     Role ID: $($assignment.roleDefinitionId)" -ForegroundColor DarkGray
        Write-Host "     End Time: $($assignment.endDateTime)" -ForegroundColor DarkGray

        if ($null -ne $assignment.endDateTime) {
            $endTime = [DateTime]::Parse($assignment.endDateTime)
            $isActive = $endTime -gt $currentTime
            Write-Host "     Is Active? $isActive (ends: $endTime)" -ForegroundColor $(if($isActive){'Yellow'}else{'DarkGray'})

            if ($isActive) {
                $activeRoleIds += $assignment.roleDefinitionId
            }
        }
    }
}

Write-Host ""
Write-Host "   Active role IDs being filtered out: $($activeRoleIds.Count)" -ForegroundColor Yellow
if ($activeRoleIds.Count -gt 0) {
    $activeRoleIds | ForEach-Object { Write-Host "     - $_" -ForegroundColor DarkGray }
}
Write-Host ""

# Query pending roles
Write-Host "3. Querying PENDING roles..." -ForegroundColor Cyan
try {
    $pendingResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests?`$filter=principalId eq '$userId' and status eq 'PendingApproval'&`$select=roleDefinitionId" -ErrorAction Stop
    $pendingRoleIds = @()
    if ($pendingResponse -and $pendingResponse.value) {
        $pendingRoleIds = @($pendingResponse.value | Select-Object -ExpandProperty roleDefinitionId -Unique)
    }
} catch {
    $pendingRoleIds = @()
}

Write-Host "   Pending role IDs being filtered out: $($pendingRoleIds.Count)" -ForegroundColor Yellow
if ($pendingRoleIds.Count -gt 0) {
    $pendingRoleIds | ForEach-Object { Write-Host "     - $_" -ForegroundColor DarkGray }
}
Write-Host ""

# Show filtering logic
Write-Host "4. Applying filtering logic..." -ForegroundColor Cyan
Write-Host ""

$allEligibleRoleIds = $eligibilitySchedules | Select-Object -ExpandProperty roleDefinitionId
Write-Host "   Total eligible role IDs: $($allEligibleRoleIds.Count)" -ForegroundColor White

$filteredOut = 0
foreach ($roleId in $allEligibleRoleIds) {
    $isActive = $activeRoleIds -contains $roleId
    $isPending = $pendingRoleIds -contains $roleId
    $willBeFiltered = $isActive -or $isPending

    if ($willBeFiltered) {
        $filteredOut++
        $reason = if ($isActive) { "ACTIVE" } elseif ($isPending) { "PENDING" } else { "UNKNOWN" }
        Write-Host "   ❌ Filtering out $roleId (Reason: $reason)" -ForegroundColor Red
    } else {
        Write-Host "   ✅ Keeping $roleId" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "5. FINAL RESULT:" -ForegroundColor Cyan
Write-Host "   Started with: $($allEligibleRoleIds.Count) eligible roles" -ForegroundColor White
Write-Host "   Filtered out: $filteredOut roles" -ForegroundColor Yellow
Write-Host "   Remaining: $($allEligibleRoleIds.Count - $filteredOut) roles" -ForegroundColor $(if(($allEligibleRoleIds.Count - $filteredOut) -eq 0){'Red'}else{'Green'})
Write-Host ""

if (($allEligibleRoleIds.Count - $filteredOut) -eq 0 -and $allEligibleRoleIds.Count -gt 0) {
    Write-Host "⚠️  ALL ELIGIBLE ROLES WERE FILTERED OUT!" -ForegroundColor Red
    Write-Host "This is the bug causing '0 eligible roles' in Start-EntraPIM" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Diagnostic Complete ===" -ForegroundColor Cyan
Write-Host ""
