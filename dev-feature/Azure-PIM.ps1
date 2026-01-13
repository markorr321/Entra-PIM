<#
    Azure Resources PIM Manager Script (Activation + Deactivation)
    ---------------------------------------------------------------
    - Self-activate eligible Azure resource roles (Subscriptions, Resource Groups, Resources)
    - Deactivate active Azure resource role assignments
    - Supports justification and custom duration
    - MFA-enforced Azure AD login
#>

# ========================= Global Variables =========================

$script:AzureContext = $null
$script:CurrentUserId = $null
$script:EligibleRoleCache = @()
$script:EligibleRoleCacheTime = $null
$script:ActiveRoleCache = @()
$script:ActiveRoleCacheTime = $null

# Cache expiry in seconds
$script:CacheExpirySeconds = 60

# Control bar tracking
$script:LastControlBarLine = -1

# Control message constants
$script:ControlMessages = @{
    'Exit' = "Ctrl+Q Exit"
    'Navigation' = "↑/↓ Navigate | SPACE Toggle | ENTER Confirm | Ctrl+Q Exit"
    'Input' = "Ctrl+Q Exit | ESC Cancel"
}

# ========================= UI Components =========================

function Show-Header {
    Write-Host "[ P I M - A Z U R E   R E S O U R C E S ]" -ForegroundColor DarkMagenta
}

function Invoke-Exit {
    param([string]$Message = "Exiting...")
    
    [Console]::CursorVisible = $true
    Clear-Host
    Write-Host $Message -ForegroundColor Yellow
    
    try {
        Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
        Write-Host "✅ Disconnected from Azure." -ForegroundColor Green
    } catch {
        Write-Host "ℹ️ Already disconnected." -ForegroundColor DarkGray
    }
    
    Write-Host "Terminal will close in 2 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    [Environment]::Exit(0)
}

function Test-GlobalShortcut {
    param([System.ConsoleKeyInfo]$Key)
    
    if ($Key.Key -eq 'Q' -and $Key.Modifiers -eq 'Control') {
        Invoke-Exit
        return $true
    }
    return $false
}

function Show-CheckboxMenu {
    param(
        [array]$Items,
        [string]$Title = "Select Items",
        [switch]$SingleSelection
    )
    
    if ($Items.Count -eq 0) {
        Write-Status "No items available" -Type "Warning"
        return @()
    }
    
    $selected = @{}
    $currentIndex = 0
    
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $selected[$i] = $false
    }
    
    [Console]::CursorVisible = $false
    
    try {
        do {
            Clear-Host
            
            # Show header
            Show-Header
            Write-Host ""
            Write-Host $Title -ForegroundColor Cyan
            Write-Host ("-" * $Title.Length) -ForegroundColor Cyan
            Write-Host ""
            
            # Show items
            for ($i = 0; $i -lt $Items.Count; $i++) {
                $item = $Items[$i]
                $checkbox = if ($selected[$i]) { "[✓]" } else { "[ ]" }
                $arrow = if ($i -eq $currentIndex) { "► " } else { "  " }
                $color = if ($i -eq $currentIndex) { "Yellow" } else { "White" }
                $checkboxColor = if ($selected[$i]) { "Green" } else { "Gray" }
                
                $displayText = if ($item.RoleDisplayName -and $item.ScopeDisplayName) { "$($item.RoleDisplayName) - $($item.ScopeDisplayName)" } elseif ($item.RoleDisplayName) { $item.RoleDisplayName } elseif ($item.ToString) { $item.ToString() } else { $item }
                
                Write-Host "$arrow" -NoNewline -ForegroundColor $color
                Write-Host "$checkbox " -NoNewline -ForegroundColor $checkboxColor
                Write-Host "$displayText" -ForegroundColor $color
            }
            
            # Show selected count
            Write-Host ""
            $selectedCount = ($selected.Values | Where-Object { $_ }).Count
            Write-Host "Selected: $selectedCount" -ForegroundColor Cyan
            
            # Dynamic control bar - position right below content
            Write-Host ""
            Write-Host $script:ControlMessages['Navigation'] -ForegroundColor Magenta
            
            $key = [Console]::ReadKey($true)
            
            if (Test-GlobalShortcut -Key $key) { return @() }
            
            switch ($key.Key) {
                "UpArrow" {
                    $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $Items.Count - 1 }
                }
                "DownArrow" {
                    $currentIndex = if ($currentIndex -lt ($Items.Count - 1)) { $currentIndex + 1 } else { 0 }
                }
                "Spacebar" {
                    if ($SingleSelection) {
                        for ($i = 0; $i -lt $Items.Count; $i++) { $selected[$i] = $false }
                        $selected[$currentIndex] = $true
                    } else {
                        $selected[$currentIndex] = -not $selected[$currentIndex]
                    }
                }
                "Enter" {
                    $result = @()
                    for ($i = 0; $i -lt $Items.Count; $i++) {
                        if ($selected[$i]) { $result += $i }
                    }
                    return $result
                }
                "Escape" {
                    return @()
                }
                "A" {
                    if ($key.Modifiers -eq 'Control' -and -not $SingleSelection) {
                        for ($i = 0; $i -lt $Items.Count; $i++) { $selected[$i] = $true }
                    }
                }
                "D" {
                    if ($key.Modifiers -eq 'Control') {
                        for ($i = 0; $i -lt $Items.Count; $i++) { $selected[$i] = $false }
                    }
                }
            }
        } while ($true)
    } finally {
        [Console]::CursorVisible = $true
    }
}

function Read-InputWithControls {
    param(
        [string]$Prompt,
        [switch]$Required
    )
    
    # Show prompt
    Write-Host "${Prompt}: " -ForegroundColor Cyan -NoNewline
    $promptLeft = [Console]::CursorLeft
    $promptTop = [Console]::CursorTop
    
    # Dynamic control bar - position right below prompt
    Write-Host ""
    Write-Host ""
    Write-Host $script:ControlMessages['Input'] -ForegroundColor Magenta
    $script:LastControlBarLine = [Console]::CursorTop - 1
    
    # Return cursor to input position
    [Console]::SetCursorPosition($promptLeft, $promptTop)
    
    $inputText = ""
    do {
        $key = [Console]::ReadKey($true)
        
        if (Test-GlobalShortcut -Key $key) { return $null }
        
        if ($key.Key -eq 'Escape') { return $null }
        
        if ($key.Key -eq 'Enter') {
            Write-Host ""
            # Clear the control bar when input is complete
            if ($script:LastControlBarLine -ge 0) {
                try {
                    [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                    Write-Host (" " * [Console]::WindowWidth) -NoNewline
                    [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                    $script:LastControlBarLine = -1
                } catch { }
            }
            break
        }
        
        if ($key.Key -eq 'Backspace' -and $inputText.Length -gt 0) {
            $inputText = $inputText.Substring(0, $inputText.Length - 1)
            Write-Host "`b `b" -NoNewline
        }
        elseif ($key.KeyChar -ne "`0" -and [char]::IsControl($key.KeyChar) -eq $false) {
            $inputText += $key.KeyChar
            Write-Host $key.KeyChar -NoNewline -ForegroundColor White
        }
    } while ($true)
    
    if ($Required -and [string]::IsNullOrWhiteSpace($inputText)) {
        Write-Status "Input is required" -Type "Error"
        return Read-InputWithControls -Prompt $Prompt -Required:$Required
    }
    
    return $inputText
}

function Show-DeactivationCountdown {
    param(
        [array]$Roles
    )
    
    [Console]::CursorVisible = $false
    
    try {
        # Find the role with the longest wait time
        $maxWaitRole = $Roles | Sort-Object WaitSeconds -Descending | Select-Object -First 1
        $targetTime = $maxWaitRole.ActivatedTime.AddMinutes(5)
        
        do {
            [Console]::Clear()
            [Console]::SetCursorPosition(0, 0)
            Show-Header
            Write-Host ""
            Write-Host "Waiting for 5-minute rule..." -ForegroundColor Yellow
            Write-Host ""
            
            $now = Get-Date
            $allReady = $true
            
            foreach ($role in $Roles) {
                $roleTargetTime = $role.ActivatedTime.AddMinutes(5)
                $remaining = $roleTargetTime - $now
                
                if ($remaining.TotalSeconds -gt 0) {
                    $allReady = $false
                    $mins = [Math]::Floor($remaining.TotalMinutes)
                    $secs = [Math]::Floor($remaining.Seconds)
                    Write-Host "   ⏳ $($role.RoleDisplayName) - $($role.ScopeDisplayName) - " -NoNewline -ForegroundColor White
                    Write-Host "${mins}m ${secs}s" -ForegroundColor Yellow
                } else {
                    Write-Host "   ✅ $($role.RoleDisplayName) - $($role.ScopeDisplayName) - Ready!" -ForegroundColor Green
                }
            }
            
            # Dynamic control bar - position right below content
            Write-Host ""
            Write-Host "Ctrl+Q Exit | ESC Cancel countdown" -ForegroundColor Magenta
            
            if ($allReady) {
                Write-Host ""
                Write-Status "All roles ready for deactivation!" -Type "Success"
                Start-Sleep -Milliseconds 500
                return
            }
            
            # Check for key press (non-blocking)
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if (Test-GlobalShortcut -Key $key) { return }
                if ($key.Key -eq 'Escape') { return }
            }
            
            Start-Sleep -Milliseconds 1000
            
        } while ($true)
        
    } finally {
        [Console]::CursorVisible = $true
    }
}

# ========================= Helper Functions =========================

function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    switch ($Type) {
        "Success" { Write-Host "✅ $Message" -ForegroundColor Green }
        "Error"   { Write-Host "❌ $Message" -ForegroundColor Red }
        "Warning" { Write-Host "⚠️ $Message" -ForegroundColor Yellow }
        "Info"    { Write-Host "ℹ️ $Message" -ForegroundColor Cyan }
        "Working" { Write-Host "🔄 $Message" -ForegroundColor Cyan }
        default   { Write-Host $Message }
    }
}

function Invoke-AzurePIMApi {
    <#
    .SYNOPSIS
        Calls Azure PIM REST API using Invoke-AzRestMethod for reliable authentication
    #>
    param(
        [string]$Method = "GET",
        [string]$Path,
        [object]$Body = $null
    )
    
    try {
        $params = @{
            Path   = $Path
            Method = $Method
        }
        
        if ($Body) {
            $params.Payload = $Body | ConvertTo-Json -Depth 10
        }
        
        $response = Invoke-AzRestMethod @params
        
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            if ($response.Content) {
                return $response.Content | ConvertFrom-Json
            }
            return $true
        } else {
            $errorContent = $response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($errorContent.error.message) {
                throw $errorContent.error.message
            }
            throw "API call failed with status code: $($response.StatusCode)"
        }
    } catch {
        throw $_.Exception.Message
    }
}

# ========================= Core PIM Functions =========================

function Get-AzureEligibleRoles {
    <#
    .SYNOPSIS
        Gets all eligible Azure resource role assignments for the current user
    #>
    param(
        [switch]$Force
    )
    
    # Check cache
    if (-not $Force -and $script:EligibleRoleCache.Count -gt 0 -and $script:EligibleRoleCacheTime) {
        $cacheAge = (Get-Date) - $script:EligibleRoleCacheTime
        if ($cacheAge.TotalSeconds -lt $script:CacheExpirySeconds) {
            return $script:EligibleRoleCache
        }
    }
    
    try {
        # Use pre-selected subscriptions from authentication
        if (-not $script:SelectedSubscriptions -or $script:SelectedSubscriptions.Count -eq 0) {
            return @()
        }
        
        $subscriptions = $script:SelectedSubscriptions
        
        $allEligibleRoles = @()
        
        foreach ($sub in $subscriptions) {
            # Set context to this subscription to ensure valid token
            Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue | Out-Null
            
            $path = "/subscriptions/$($sub.Id)/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?api-version=2020-10-01&`$filter=asTarget()"
            
            try {
                $response = Invoke-AzurePIMApi -Path $path -Method "GET"
                
                if ($response.value) {
                    foreach ($role in $response.value) {
                        $allEligibleRoles += [PSCustomObject]@{
                            Id                    = $role.id
                            Name                  = $role.name
                            RoleDefinitionId      = $role.properties.roleDefinitionId
                            RoleDisplayName       = $role.properties.expandedProperties.roleDefinition.displayName
                            Scope                 = $role.properties.scope
                            ScopeDisplayName      = $role.properties.expandedProperties.scope.displayName
                            ScopeType             = $role.properties.expandedProperties.scope.type
                            PrincipalId           = $role.properties.principalId
                            PrincipalType         = $role.properties.principalType
                            StartDateTime         = $role.properties.startDateTime
                            EndDateTime           = $role.properties.endDateTime
                            MemberType            = $role.properties.memberType
                            SubscriptionId        = $sub.Id
                            SubscriptionName      = $sub.Name
                        }
                    }
                }
            } catch {
                Write-Status "Could not query subscription '$($sub.Name)': $($_.Exception.Message)" -Type "Warning"
            }
        }
        
        # Cache the results
        $script:EligibleRoleCache = $allEligibleRoles
        $script:EligibleRoleCacheTime = Get-Date
        
        return $allEligibleRoles
        
    } catch {
        Write-Status "Error fetching eligible roles: $($_.Exception.Message)" -Type "Error"
        return @()
    }
}

function Get-AzureActiveRoles {
    <#
    .SYNOPSIS
        Gets all active (activated) Azure resource role assignments for the current user
    #>
    param(
        [switch]$Force
    )
    
    # Check cache
    if (-not $Force -and $script:ActiveRoleCache.Count -gt 0 -and $script:ActiveRoleCacheTime) {
        $cacheAge = (Get-Date) - $script:ActiveRoleCacheTime
        if ($cacheAge.TotalSeconds -lt $script:CacheExpirySeconds) {
            return $script:ActiveRoleCache
        }
    }
    
    try {
        # Use pre-selected subscriptions from authentication
        if (-not $script:SelectedSubscriptions -or $script:SelectedSubscriptions.Count -eq 0) {
            return @()
        }
        
        $subscriptions = $script:SelectedSubscriptions
        
        $allActiveRoles = @()
        
        foreach ($sub in $subscriptions) {
            # Set context to this subscription to ensure valid token
            Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue | Out-Null
            
            $path = "/subscriptions/$($sub.Id)/providers/Microsoft.Authorization/roleAssignmentScheduleInstances?api-version=2020-10-01&`$filter=asTarget()"
            
            try {
                $response = Invoke-AzurePIMApi -Path $path -Method "GET"
                
                if ($response.value) {
                    foreach ($role in $response.value) {
                        # Only include activated assignments (not permanent)
                        if ($role.properties.assignmentType -eq "Activated") {
                            $allActiveRoles += [PSCustomObject]@{
                                Id                    = $role.id
                                Name                  = $role.name
                                RoleDefinitionId      = $role.properties.roleDefinitionId
                                RoleDisplayName       = $role.properties.expandedProperties.roleDefinition.displayName
                                Scope                 = $role.properties.scope
                                ScopeDisplayName      = $role.properties.expandedProperties.scope.displayName
                                ScopeType             = $role.properties.expandedProperties.scope.type
                                PrincipalId           = $role.properties.principalId
                                StartDateTime         = $role.properties.startDateTime
                                EndDateTime           = $role.properties.endDateTime
                                AssignmentType        = $role.properties.assignmentType
                                MemberType            = $role.properties.memberType
                                SubscriptionId        = $sub.Id
                                SubscriptionName      = $sub.Name
                            }
                        }
                    }
                }
            } catch {
                Write-Status "Could not query subscription '$($sub.Name)': $($_.Exception.Message)" -Type "Warning"
            }
        }
        
        # Cache the results
        $script:ActiveRoleCache = $allActiveRoles
        $script:ActiveRoleCacheTime = Get-Date
        
        return $allActiveRoles
        
    } catch {
        Write-Status "Error fetching active roles: $($_.Exception.Message)" -Type "Error"
        return @()
    }
}

function Start-AzureRoleActivation {
    <#
    .SYNOPSIS
        Activates an eligible Azure resource role
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$EligibleRole,
        
        [Parameter(Mandatory)]
        [string]$Justification,
        
        [Parameter(Mandatory)]
        [string]$Duration  # ISO 8601 format, e.g., "PT1H" for 1 hour
    )
    
    Write-Status "Activating: $($EligibleRole.RoleDisplayName) - $($EligibleRole.ScopeDisplayName)" -Type "Working"
    
    try {
        # Set subscription context before API call
        Set-AzContext -SubscriptionId $EligibleRole.SubscriptionId -ErrorAction SilentlyContinue | Out-Null
        
        $scope = $EligibleRole.Scope
        $requestName = [guid]::NewGuid().ToString()
        
        $path = "${scope}/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/${requestName}?api-version=2020-10-01"
        
        $body = @{
            properties = @{
                principalId                     = $EligibleRole.PrincipalId
                roleDefinitionId                = $EligibleRole.RoleDefinitionId
                requestType                     = "SelfActivate"
                justification                   = $Justification
                scope                           = $scope
                scheduleInfo                    = @{
                    startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    expiration    = @{
                        type     = "AfterDuration"
                        duration = $Duration
                    }
                }
            }
        }
        
        $response = Invoke-AzurePIMApi -Path $path -Method "PUT" -Body $body
        
        if ($response) {
            Write-Status "Activated: $($EligibleRole.RoleDisplayName) - $($EligibleRole.ScopeDisplayName)" -Type "Success"
            
            # Clear cache
            $script:ActiveRoleCache = @()
            $script:ActiveRoleCacheTime = $null
            
            return $true
        }
        
        return $false
        
    } catch {
        Write-Status "Failed to activate role: $($_.Exception.Message)" -Type "Error"
        return $false
    }
}

function Stop-AzureRoleActivation {
    <#
    .SYNOPSIS
        Deactivates an active Azure resource role
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ActiveRole
    )
    
    Write-Status "Deactivating: $($ActiveRole.RoleDisplayName)..." -Type "Working"
    
    try {
        # Set subscription context before API call
        Set-AzContext -SubscriptionId $ActiveRole.SubscriptionId -ErrorAction SilentlyContinue | Out-Null
        
        $scope = $ActiveRole.Scope
        $requestName = [guid]::NewGuid().ToString()
        
        $path = "${scope}/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/${requestName}?api-version=2020-10-01"
        
        $body = @{
            properties = @{
                principalId      = $ActiveRole.PrincipalId
                roleDefinitionId = $ActiveRole.RoleDefinitionId
                requestType      = "SelfDeactivate"
            }
        }
        
        $response = Invoke-AzurePIMApi -Path $path -Method "PUT" -Body $body
        
        if ($response) {
            Write-Status "Deactivated: $($ActiveRole.RoleDisplayName)" -Type "Success"
            
            # Clear cache
            $script:ActiveRoleCache = @()
            $script:ActiveRoleCacheTime = $null
            
            return $true
        }
        
        return $false
        
    } catch {
        Write-Status "Failed to deactivate role: $($_.Exception.Message)" -Type "Error"
        return $false
    }
}

function Convert-DurationToISO8601 {
    <#
    .SYNOPSIS
        Converts user-friendly duration format to ISO 8601
    .EXAMPLE
        Convert-DurationToISO8601 -Duration "1H"      # Returns "PT1H"
        Convert-DurationToISO8601 -Duration "30M"     # Returns "PT30M"
        Convert-DurationToISO8601 -Duration "2H30M"   # Returns "PT2H30M"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Duration
    )
    
    $Duration = $Duration.ToUpper().Trim()
    
    # Already in ISO format
    if ($Duration -match '^PT\d+[HM]') {
        return $Duration
    }
    
    # Convert friendly format
    $hours = 0
    $minutes = 0
    
    if ($Duration -match '(\d+)H') {
        $hours = [int]$matches[1]
    }
    if ($Duration -match '(\d+)M') {
        $minutes = [int]$matches[1]
    }
    
    if ($hours -eq 0 -and $minutes -eq 0) {
        # Default to 1 hour if no valid duration parsed
        return "PT1H"
    }
    
    $iso = "PT"
    if ($hours -gt 0) { $iso += "${hours}H" }
    if ($minutes -gt 0) { $iso += "${minutes}M" }
    
    return $iso
}

function Get-DurationMinutes {
    <#
    .SYNOPSIS
        Gets total minutes from duration string
    #>
    param([string]$Duration)
    
    $Duration = $Duration.ToUpper()
    $totalMinutes = 0
    
    if ($Duration -match '(\d+)H') {
        $totalMinutes += [int]$matches[1] * 60
    }
    if ($Duration -match '(\d+)M') {
        $totalMinutes += [int]$matches[1]
    }
    
    return $totalMinutes
}

# ========================= Main Menu =========================

function Show-MainMenu {
    $menuItems = @("Activate Roles", "Deactivate Roles")
    $selectedIndices = Show-CheckboxMenu -Items $menuItems -Title "Choose Action" -SingleSelection
    
    if ($selectedIndices.Count -eq 0) {
        return "Q"
    }
    
    switch ($selectedIndices[0]) {
        0 { return "1" }
        1 { return "2" }
        default { return "Q" }
    }
}

function Show-RoleSelectionMenu {
    param(
        [array]$Roles,
        [string]$Title
    )
    
    if ($Roles.Count -eq 0) {
        Write-Status "No roles available" -Type "Warning"
        return @()
    }
    
    $selectedIndices = Show-CheckboxMenu -Items $Roles -Title $Title
    
    if ($selectedIndices.Count -eq 0) {
        return @()
    }
    
    return $Roles[$selectedIndices]
}

function Start-ActivationWorkflow {
    # Clear screen and reset cursor before fetching
    [Console]::Clear()
    [Console]::SetCursorPosition(0, 0)
    Show-Header
    Write-Host ""
    
    $eligibleRoles = Get-AzureEligibleRoles
    
    if ($eligibleRoles.Count -eq 0) {
        Write-Status "No eligible roles found for activation" -Type "Warning"
        Write-Host ""
        $continue = Read-InputWithControls -Prompt "Manage more roles? (Y/N)"
        if ($continue -and $continue.ToUpper() -eq "Y") {
            return
        } else {
            Invoke-Exit
        }
        return
    }
    
    # Filter out roles that are already active
    $activeRoles = Get-AzureActiveRoles
    $activeRoleKeys = $activeRoles | ForEach-Object { "$($_.RoleDefinitionId)|$($_.Scope)" }
    
    $availableRoles = $eligibleRoles | Where-Object {
        $key = "$($_.RoleDefinitionId)|$($_.Scope)"
        $activeRoleKeys -notcontains $key
    }
    
    if ($availableRoles.Count -eq 0) {
        Write-Status "All eligible roles are already activated" -Type "Info"
        Write-Host ""
        $continue = Read-InputWithControls -Prompt "Manage more roles? (Y/N)"
        if ($continue -and $continue.ToUpper() -eq "Y") {
            return
        } else {
            Invoke-Exit
        }
        return
    }
    
    $selectedRoles = Show-RoleSelectionMenu -Roles $availableRoles -Title "Select Roles to Activate"
    
    if (-not $selectedRoles -or $selectedRoles.Count -eq 0) {
        return
    }
    
    # Get duration
    Clear-Host
    Show-Header
    Write-Host ""
    Write-Host "Activating $($selectedRoles.Count) role(s)" -ForegroundColor Cyan
    Write-Host ""
    
    $durationInput = Read-InputWithControls -Prompt "Duration (e.g., 1H, 30M, 2H30M)"
    if (-not $durationInput) { return }
    
    if ([string]::IsNullOrWhiteSpace($durationInput)) {
        $durationInput = "1H"
        Write-Status "Using default: 1 hour" -Type "Info"
    }
    
    $totalMinutes = Get-DurationMinutes -Duration $durationInput
    if ($totalMinutes -lt 5) {
        Write-Status "Minimum 5 minutes. Using 5M." -Type "Warning"
        $durationInput = "5M"
    }
    
    $duration = Convert-DurationToISO8601 -Duration $durationInput
    
    # Get justification
    Clear-Host
    Show-Header
    Write-Host ""
    Write-Host "Activating $($selectedRoles.Count) role(s)" -ForegroundColor Cyan
    Write-Host "Duration: $durationInput" -ForegroundColor Gray
    Write-Host ""
    $justification = Read-InputWithControls -Prompt "Justification" -Required
    if (-not $justification) { return }
    
    # Activate each selected role
    Write-Host ""
    $successCount = 0
    $failCount = 0
    
    foreach ($role in $selectedRoles) {
        $result = Start-AzureRoleActivation -EligibleRole $role -Justification $justification -Duration $duration
        if ($result) {
            $successCount++
        } else {
            $failCount++
        }
    }
    
    Write-Host ""
    Write-Status "Activation complete: $successCount succeeded, $failCount failed" -Type $(if ($failCount -eq 0) { "Success" } else { "Warning" })
    
    # Ask if user wants to manage more roles
    Write-Host ""
    $continue = Read-InputWithControls -Prompt "Manage more roles? (Y/N)"
    if ($continue -and $continue.ToUpper() -eq "Y") {
        return  # Return to main menu
    } else {
        Invoke-Exit
    }
}

function Start-DeactivationWorkflow {
    # Clear screen and reset cursor before fetching
    [Console]::Clear()
    [Console]::SetCursorPosition(0, 0)
    Show-Header
    Write-Host ""
    
    $activeRoles = Get-AzureActiveRoles -Force
    
    if ($activeRoles.Count -eq 0) {
        Write-Status "No active roles found for deactivation" -Type "Warning"
        Write-Host ""
        $continue = Read-InputWithControls -Prompt "Manage more roles? (Y/N)"
        if ($continue -and $continue.ToUpper() -eq "Y") {
            return
        } else {
            Invoke-Exit
        }
        return
    }
    
    # Filter roles - check 5-minute rule
    $readyRoles = @()
    $tooNewRoles = @()
    $now = Get-Date
    
    foreach ($role in $activeRoles) {
        if ($role.StartDateTime) {
            # Azure returns UTC time without timezone indicator - specify it's UTC then convert to local
            $activatedTimeUtc = [DateTime]::SpecifyKind([DateTime]::Parse($role.StartDateTime), [DateTimeKind]::Utc)
            $activatedTime = $activatedTimeUtc.ToLocalTime()
            $elapsed = $now - $activatedTime
            if ($elapsed.TotalMinutes -lt 5) {
                $remainingSeconds = [Math]::Ceiling((5 * 60) - $elapsed.TotalSeconds)
                $role | Add-Member -NotePropertyName "WaitSeconds" -NotePropertyValue $remainingSeconds -Force
                $role | Add-Member -NotePropertyName "ActivatedTime" -NotePropertyValue $activatedTime -Force
                $tooNewRoles += $role
            } else {
                $readyRoles += $role
            }
        } else {
            $readyRoles += $role
        }
    }
    
    # If roles are too new, show countdown
    if ($tooNewRoles.Count -gt 0 -and $readyRoles.Count -eq 0) {
        Show-DeactivationCountdown -Roles $tooNewRoles
        # After countdown, refresh and continue
        return Start-DeactivationWorkflow
    }
    
    if ($tooNewRoles.Count -gt 0) {
        Write-Host ""
        Write-Status "Some roles still waiting (5-min rule):" -Type "Warning"
        foreach ($role in $tooNewRoles) {
            $mins = [Math]::Floor($role.WaitSeconds / 60)
            $secs = $role.WaitSeconds % 60
            Write-Host "   • $($role.RoleDisplayName) - $($role.ScopeDisplayName) - ${mins}m ${secs}s remaining" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    if ($readyRoles.Count -eq 0) {
        Write-Status "No roles ready for deactivation yet" -Type "Info"
        Write-Host ""
        $continue = Read-InputWithControls -Prompt "Manage more roles? (Y/N)"
        if ($continue -and $continue.ToUpper() -eq "Y") {
            return
        } else {
            Invoke-Exit
        }
        return
    }
    
    $selectedRoles = Show-RoleSelectionMenu -Roles $readyRoles -Title "Select Roles to Deactivate"
    
    if (-not $selectedRoles -or $selectedRoles.Count -eq 0) {
        return
    }
    
    # Clear screen and deactivate each selected role
    [Console]::Clear()
    [Console]::SetCursorPosition(0, 0)
    Show-Header
    Write-Host ""
    $successCount = 0
    $failCount = 0
    
    foreach ($role in $selectedRoles) {
        $result = Stop-AzureRoleActivation -ActiveRole $role
        if ($result) {
            $successCount++
        } else {
            $failCount++
        }
    }
    
    Write-Host ""
    Write-Status "Deactivation complete: $successCount succeeded, $failCount failed" -Type $(if ($failCount -eq 0) { "Success" } else { "Warning" })
    
    # Ask if user wants to manage more roles
    Write-Host ""
    $continue = Read-InputWithControls -Prompt "Manage more roles? (Y/N)"
    if ($continue -and $continue.ToUpper() -eq "Y") {
        return  # Return to main menu
    } else {
        Invoke-Exit
    }
}

# ========================= Main Script =========================

Clear-Host
Write-Host ""
Write-Host "[ P I M - A Z U R E   R E S O U R C E S ]" -ForegroundColor DarkMagenta
Write-Host "Azure PIM Self-Activation for Azure Resources" -ForegroundColor Green
Write-Host ""

# Check for Az module
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Status "Az.Accounts module not found. Installing..." -Type "Working"
    Install-Module Az.Accounts -Scope CurrentUser -Force
}

# Import required modules
Import-Module Az.Accounts -ErrorAction SilentlyContinue

# Authenticate with fresh interactive login to handle MFA
Write-Status "Connecting to Azure..." -Type "Working"
Write-Host "   (A browser window will open for authentication)" -ForegroundColor Gray
Write-Host ""

try {
    # Force disconnect any existing sessions to get fresh MFA token
    Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
    
    # Interactive login - this will trigger MFA if required
    $loginResult = Connect-AzAccount -ErrorAction Stop
    
    $context = Get-AzContext
    if (-not $context) {
        throw "Failed to establish Azure context"
    }
    
    Write-Status "Connected as: $($context.Account.Id)" -Type "Success"
    Write-Host "   Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
    
    # Check if user has access to multiple tenants
    $tenants = Get-AzTenant -ErrorAction SilentlyContinue
    
    if ($tenants.Count -gt 1) {
        Write-Host ""
        Write-Host "Multiple tenants detected. Current tenant: $($context.Tenant.Id)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Available Tenants:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $tenants.Count; $i++) {
            $marker = if ($tenants[$i].Id -eq $context.Tenant.Id) { " (current)" } else { "" }
            Write-Host "  [$($i + 1)] $($tenants[$i].Name) - $($tenants[$i].Id)$marker" -ForegroundColor White
        }
        Write-Host ""
        $tenantChoice = Read-Host "Switch tenant? Enter number or press Enter to keep current"
        
        if ($tenantChoice -match '^\d+$') {
            $selectedIndex = [int]$tenantChoice - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $tenants.Count) {
                $selectedTenant = $tenants[$selectedIndex]
                if ($selectedTenant.Id -ne $context.Tenant.Id) {
                    Write-Status "Switching to tenant: $($selectedTenant.Name)..." -Type "Working"
                    
                    # Reconnect to specific tenant with fresh MFA
                    Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
                    Connect-AzAccount -TenantId $selectedTenant.Id -ErrorAction Stop | Out-Null
                    
                    $context = Get-AzContext
                    Write-Status "Switched to tenant: $($selectedTenant.Name)" -Type "Success"
                }
            }
        }
    }
    
    # Get subscriptions from current context (already authenticated)
    Write-Host ""
    
    # Get all subscriptions for selection - include tenant ID to ensure we get all
    $context = Get-AzContext
    $subscriptions = Get-AzSubscription -TenantId $context.Tenant.Id -ErrorAction SilentlyContinue
    
    # If still no subscriptions, try without tenant filter
    if (-not $subscriptions -or $subscriptions.Count -eq 0) {
        $subscriptions = Get-AzSubscription -ErrorAction SilentlyContinue
    }
    
    if (-not $subscriptions -or $subscriptions.Count -eq 0) {
        Write-Status "No subscriptions found" -Type "Error"
        Write-Host "   Make sure you have Reader or higher access to at least one subscription" -ForegroundColor Gray
        exit 1
    }
    
    Write-Host "Available Subscriptions:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "  [$($i + 1)] $($subscriptions[$i].Name)" -ForegroundColor White
    }
    Write-Host ""
    
    $subChoice = Read-Host "Select subscription (enter number)"
    
    $selectedIndex = $null
    if ($subChoice -match '^\d+$') {
        $selectedIndex = [int]$subChoice - 1
    }
    
    if ($null -eq $selectedIndex -or $selectedIndex -lt 0 -or $selectedIndex -ge $subscriptions.Count) {
        $selectedIndex = 0
    }
    
    $selectedSub = $subscriptions[$selectedIndex]
    $script:SelectedSubscriptions = @([PSCustomObject]@{
        Id = $selectedSub.Id
        Name = $selectedSub.Name
    })
    
    Set-AzContext -SubscriptionId $selectedSub.Id -ErrorAction SilentlyContinue | Out-Null
    Write-Status "Using: $($selectedSub.Name)" -Type "Success"
    
    Write-Host ""
    
} catch {
    Write-Status "Failed to connect to Azure: $($_.Exception.Message)" -Type "Error"
    Write-Host "" 
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure you have the Az.Accounts module installed" -ForegroundColor Gray
    Write-Host "  2. Complete MFA authentication when prompted" -ForegroundColor Gray
    Write-Host "  3. If using a specific tenant, run:" -ForegroundColor Gray
    Write-Host "     Connect-AzAccount -TenantId <your-tenant-id>" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Main loop
do {
    $choice = Show-MainMenu
    
    switch ($choice) {
        "1" { Start-ActivationWorkflow }
        "2" { Start-DeactivationWorkflow }
        "Q" { Invoke-Exit }
    }
    
} while ($true)