# ========================= Cross-Platform Keyboard Shortcuts =========================
# Detect if running on macOS
$script:IsMacOS = $IsMacOS -or ($PSVersionTable.OS -match 'Darwin')

# Cross-platform shortcut detection
function Test-QuitShortcut {
    param([System.ConsoleKeyInfo]$Key)

    if ($script:IsMacOS) {
        # On macOS: Ctrl+Q may not work, also check for Escape
        return ($Key.Key -eq 'Q' -and $Key.Modifiers -band [ConsoleModifiers]::Control) -or
               ($Key.Key -eq 'Escape')
    } else {
        # On Windows: Ctrl+Q
        return ($Key.Key -eq 'Q' -and $Key.Modifiers -eq 'Control')
    }
}

function Test-HelpShortcut {
    param([System.ConsoleKeyInfo]$Key)

    if ($script:IsMacOS) {
        # On macOS: Ctrl+H sends backspace, so use ?
        return ($Key.KeyChar -eq '?')
    } else {
        # On Windows: Ctrl+H or ?
        return ($Key.Key -eq 'H' -and $Key.Modifiers -eq 'Control') -or ($Key.KeyChar -eq '?')
    }
}

function Get-HelpShortcutText {
    if ($script:IsMacOS) {
        return "? Help"
    } else {
        return "Ctrl+H Help"
    }
}

function Get-QuitShortcutText {
    if ($script:IsMacOS) {
        return "ESC Exit"
    } else {
        return "Ctrl+Q Exit"
    }
}

# ========================= Authentication =========================
# Global variable to store assembly paths
$script:MSALAssemblyPaths = @{}

function Initialize-MSALAssemblies {
    <#
    .SYNOPSIS
        Loads MSAL assemblies for browser-based authentication (no WAM).
    #>

    # Get user home directory (cross-platform)
    $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }

    # Try to find MSAL from nuget cache first
    $nugetPath = Join-Path $userHome ".nuget/packages/microsoft.identity.client"
    $msalDll = $null
    $abstractionsDll = $null

    if (Test-Path $nugetPath) {
        # Get latest version
        $latestVersion = Get-ChildItem $nugetPath -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($latestVersion) {
            $msalDll = Join-Path $latestVersion.FullName "lib/net6.0/Microsoft.Identity.Client.dll"
            if (-not (Test-Path $msalDll)) {
                $msalDll = Join-Path $latestVersion.FullName "lib/netstandard2.0/Microsoft.Identity.Client.dll"
            }
        }

        # Find abstractions
        $abstractionsPath = Join-Path $userHome ".nuget/packages/microsoft.identitymodel.abstractions"
        if (Test-Path $abstractionsPath) {
            $latestAbstractions = Get-ChildItem $abstractionsPath -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if ($latestAbstractions) {
                $abstractionsDll = Join-Path $latestAbstractions.FullName "lib/net6.0/Microsoft.IdentityModel.Abstractions.dll"
                if (-not (Test-Path $abstractionsDll)) {
                    $abstractionsDll = Join-Path $latestAbstractions.FullName "lib/netstandard2.0/Microsoft.IdentityModel.Abstractions.dll"
                }
            }
        }
    }

    # Fallback to Az.Accounts if nuget not available
    if (-not $msalDll -or -not (Test-Path $msalDll)) {
        $LoadedAzAccountsModule = Get-Module -Name Az.Accounts
        if ($null -eq $LoadedAzAccountsModule) {
            $AzAccountsModule = Get-Module -Name Az.Accounts -ListAvailable | Select-Object -First 1
            if ($null -eq $AzAccountsModule) {
                Write-Verbose "Neither nuget cache nor Az.Accounts module found for MSAL"
                return $false
            }
            Import-Module Az.Accounts -ErrorAction SilentlyContinue -Verbose:$false
        }

        $LoadedAssemblies = [System.AppDomain]::CurrentDomain.GetAssemblies() | Select-Object -ExpandProperty Location -ErrorAction SilentlyContinue
        # Cross-platform regex - match both forward and back slashes
        $AzureCommon = $LoadedAssemblies | Where-Object { $_ -match "[/\\]Modules[/\\]Az.Accounts[/\\]" -and $_ -match "Microsoft.Azure.Common" }

        if ($AzureCommon) {
            $AzureCommonLocation = Split-Path -Parent $AzureCommon
            $foundMsal = Get-ChildItem -Path $AzureCommonLocation -Filter "Microsoft.Identity.Client.dll" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
            $foundAbstractions = Get-ChildItem -Path $AzureCommonLocation -Filter "Microsoft.IdentityModel.Abstractions.dll" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($foundMsal) { $msalDll = $foundMsal.FullName }
            if ($foundAbstractions) { $abstractionsDll = $foundAbstractions.FullName }
        }
    }

    if (-not $msalDll -or -not (Test-Path $msalDll)) {
        Write-Verbose "Could not find Microsoft.Identity.Client.dll"
        return $false
    }

    # Load assemblies
    $loadedAssembliesCheck = [System.AppDomain]::CurrentDomain.GetAssemblies()

    # Load abstractions first if available
    if ($abstractionsDll -and (Test-Path $abstractionsDll)) {
        $alreadyLoaded = $loadedAssembliesCheck | Where-Object { $_.GetName().Name -eq 'Microsoft.IdentityModel.Abstractions' }
        if (-not $alreadyLoaded) {
            try {
                [void][System.Reflection.Assembly]::LoadFrom($abstractionsDll)
                $script:MSALAssemblyPaths['Microsoft.IdentityModel.Abstractions'] = $abstractionsDll
            } catch { }
        } else {
            $script:MSALAssemblyPaths['Microsoft.IdentityModel.Abstractions'] = $alreadyLoaded.Location
        }
    }

    # Load MSAL
    $alreadyLoaded = $loadedAssembliesCheck | Where-Object { $_.GetName().Name -eq 'Microsoft.Identity.Client' }
    if (-not $alreadyLoaded) {
        try {
            [void][System.Reflection.Assembly]::LoadFrom($msalDll)
            $script:MSALAssemblyPaths['Microsoft.Identity.Client'] = $msalDll
        } catch {
            Write-Verbose "Failed to load MSAL: $_"
            return $false
        }
    } else {
        $script:MSALAssemblyPaths['Microsoft.Identity.Client'] = $alreadyLoaded.Location
    }

    return $true
}

# Global to track if MSAL helper is compiled
$script:MSALHelperCompiled = $false

function Initialize-MSALHelper {
    <#
    .SYNOPSIS
        Pre-compiles the MSAL helper C# code for browser-based authentication.
    #>

    if ($script:MSALHelperCompiled) { return $true }

    # Get referenced assemblies for Add-Type
    $referencedAssemblies = @(
        $script:MSALAssemblyPaths['Microsoft.IdentityModel.Abstractions'],
        $script:MSALAssemblyPaths['Microsoft.Identity.Client']
    ) | Where-Object { $_ }

    if ($referencedAssemblies.Count -lt 1) {
        throw "Missing required MSAL assemblies"
    }

    # Add standard assemblies
    $referencedAssemblies += @("netstandard", "System.Linq", "System.Threading.Tasks")

    # C# code for browser-based authentication (no WAM)
    $code = @"
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Identity.Client;

public class PIMBrowserAuth
{
    public static string GetAccessToken(string clientId, string[] scopes)
    {
        return GetAccessTokenWithClaims(clientId, scopes, null);
    }

    public static string GetAccessTokenWithClaims(string clientId, string[] scopes, string claims)
    {
        try
        {
            var task = Task.Run(async () => await GetAccessTokenAsync(clientId, scopes, claims));
            if (task.Wait(TimeSpan.FromSeconds(180)))
            {
                return task.Result;
            }
            throw new TimeoutException("Authentication timed out");
        }
        catch (AggregateException ae)
        {
            if (ae.InnerException != null) throw ae.InnerException;
            throw;
        }
    }

    private static async Task<string> GetAccessTokenAsync(string clientId, string[] scopes, string claims)
    {
        // Use system browser to bypass Windows PRT - forces fresh passkey auth every time
        IPublicClientApplication publicClientApp = PublicClientApplicationBuilder.Create(clientId)
            .WithRedirectUri("http://localhost")
            .Build();

        using (var cts = new CancellationTokenSource(TimeSpan.FromSeconds(180)))
        {
            var builder = publicClientApp.AcquireTokenInteractive(scopes)
                .WithPrompt(Prompt.ForceLogin)
                .WithUseEmbeddedWebView(false);

            // Add claims challenge if provided (for Conditional Access step-up)
            if (!string.IsNullOrEmpty(claims))
            {
                builder = builder.WithClaims(claims);
            }

            var result = await builder
                .ExecuteAsync(cts.Token)
                .ConfigureAwait(false);

            return result.AccessToken;
        }
    }
}
"@

    # Check if type already exists
    try {
        $null = [PIMBrowserAuth]
        $script:MSALHelperCompiled = $true
        return $true
    } catch {
        # Type doesn't exist, compile it
    }

    Add-Type -ReferencedAssemblies $referencedAssemblies -TypeDefinition $code -Language CSharp -ErrorAction Stop -IgnoreWarnings 3>$null

    $script:MSALHelperCompiled = $true
    return $true
}

function Get-BrowserAccessToken {
    <#
    .SYNOPSIS
        Gets an access token using browser-based authentication (forces fresh passkey auth).
    #>
    param(
        [string[]]$Scopes
    )

    # Ensure MSAL helper is compiled
    if (-not $script:MSALHelperCompiled) {
        $null = Initialize-MSALHelper
    }

    # Use Microsoft's well-known PowerShell public client ID (no app registration required)
    $clientId = "14d82eec-204b-4c2f-b7e8-296a70dab67e"

    # Build scopes string for Graph
    $scopeArray = $Scopes | ForEach-Object {
        if ($_ -notlike "https://*") { "https://graph.microsoft.com/$_" } else { $_ }
    }

    $accessToken = [PIMBrowserAuth]::GetAccessToken($clientId, $scopeArray)
    return $accessToken
}

function Get-BrowserAccessTokenWithClaims {
    <#
    .SYNOPSIS
        Gets an access token with claims challenge for Conditional Access step-up authentication.
    #>
    param(
        [string[]]$Scopes,
        [string]$Claims
    )

    # Ensure MSAL helper is compiled
    if (-not $script:MSALHelperCompiled) {
        $null = Initialize-MSALHelper
    }

    # Use Microsoft's well-known PowerShell public client ID (no app registration required)
    $clientId = "14d82eec-204b-4c2f-b7e8-296a70dab67e"

    # Build scopes string for Graph
    $scopeArray = $Scopes | ForEach-Object {
        if ($_ -notlike "https://*") { "https://graph.microsoft.com/$_" } else { $_ }
    }

    $accessToken = [PIMBrowserAuth]::GetAccessTokenWithClaims($clientId, $scopeArray, $Claims)
    return $accessToken
}

# ========================= Browser Authentication =========================
function Connect-MgGraphWithBrowser {
    param(
        [string[]]$Scopes
    )

    try {
        # Clear any existing Graph context first
        try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }

        Write-Host "Opening browser for authentication..." -ForegroundColor Cyan

        # Use custom MSAL helper for browser auth with forced login
        if ($script:MSALHelperCompiled) {
            Write-Host "Waiting for authentication response..." -ForegroundColor Yellow
            $accessToken = Get-BrowserAccessToken -Scopes $Scopes
            if ($accessToken) {
                Write-Host "Authentication successful, connecting to Graph..." -ForegroundColor Cyan
                $secureToken = ConvertTo-SecureString $accessToken -AsPlainText -Force
                Connect-MgGraph -AccessToken $secureToken -NoWelcome -ErrorAction Stop
            } else {
                throw "Failed to get access token"
            }
        } else {
            throw "MSAL helper not initialized - could not find Microsoft.Identity.Client.dll"
        }
        
        $context = Get-MgContext
        if ($context) {
            Write-Host "  Connected" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  Connection failed" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ========================= Global Variables =========================

# Global cache for role definitions to avoid repeated API calls
if (-not $script:RoleDefinitionCache) {
    $script:RoleDefinitionCache = @{}
    $script:RoleDefinitionsBatched = $false
}

# Shared schedule instance cache to avoid duplicate API calls
if (-not $script:ScheduleInstanceCache) {
    $script:ScheduleInstanceCache = @{}
    $script:ScheduleInstanceCacheExpiry = (Get-Date).AddSeconds(30)
}

# CLEANUP: Consolidated Y/N prompt helper function
function Show-YesNoPrompt {
    param(
        [string]$Question,
        [string]$YesAction = "Yes",
        [string]$NoAction = "No"
    )
    
    [Console]::CursorVisible = $true
    $response = Read-PIMInput -Prompt $Question -ControlsText "Y/N to choose | $(Get-QuitShortcutText)"
    
    if ($response) {
        $userInput = $response.Trim().ToUpper()
        if ($userInput -eq "Y" -or $userInput -eq "YES") {
            return "Yes"
        } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
            return "No"
        }
    }
    return $null
}

# CLEANUP: Consolidated "no workflows available" exit handler
function Show-NoWorkflowsAndWaitForExit {
    Write-Host "❌ No role management workflows available." -ForegroundColor Red
    Write-Host ""
    Write-Host "Check back later when roles are approved or activated." -ForegroundColor Gray
    Show-DynamicControlBar
    
    [Console]::CursorVisible = $false
    do {
        $key = [Console]::ReadKey($true)
        if (Test-QuitShortcut -Key $key) {
            Invoke-PIMExit -Message "Exiting PIM role management..."
        }
    } while ($true)
}

# OPTIMIZATION: Batch load ALL role definitions at once (called once after auth)
function Initialize-RoleDefinitionCache {
    if ($script:RoleDefinitionsBatched) {
        return  # Already loaded
    }
    
    try {
        Write-Host "📦 Loading role definitions..." -ForegroundColor Cyan -NoNewline
        $allRoleDefs = Get-MgRoleManagementDirectoryRoleDefinition -All
        $script:RoleDefinitionCache = @{}
        foreach ($roleDef in $allRoleDefs) {
            $script:RoleDefinitionCache[$roleDef.Id] = $roleDef
        }
        $script:RoleDefinitionsBatched = $true
        Write-Host " ✅ Loaded $($allRoleDefs.Count) definitions" -ForegroundColor Green
    } catch {
        Write-Host " ⚠️ Failed to batch load, will fetch individually" -ForegroundColor Yellow
        $script:RoleDefinitionsBatched = $false
    }
}

function Get-CachedRoleDefinition {
    param([string]$RoleId)
    
    # Validate input parameter
    if ([string]::IsNullOrEmpty($RoleId)) {
        return $null
    }
    
    # Return cached result if available (from batch load)
    if ($script:RoleDefinitionCache.ContainsKey($RoleId)) {
        return $script:RoleDefinitionCache[$RoleId]
    }
    
    # Fallback: Fetch individually if not in cache (shouldn't happen after batch load)
    try {
        $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $RoleId
        $script:RoleDefinitionCache[$RoleId] = $roleDefinition
        return $roleDefinition
    } catch {
        $script:RoleDefinitionCache[$RoleId] = $null
        return $null
    }
}

function Get-CachedScheduleInstances {
    param([string]$CurrentUserId)
    
    # ALWAYS fetch fresh data for deactivation - no caching
    try {
        $scheduleInstances = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -Filter "PrincipalId eq '$CurrentUserId' and AssignmentType eq 'Activated'" -All
        return $scheduleInstances
    } catch {
        return @()
    }
}

# OPTIMIZATION: Fast active role retrieval for deactivation workflow
function Get-ActiveRolesOptimized {
    param([string]$CurrentUserId)
    
    $activeRoles = @()
    try {
        # Fresh API call - no cache
        $scheduleInstances = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -Filter "PrincipalId eq '$CurrentUserId' and AssignmentType eq 'Activated'" -All
        
        # Use pre-loaded role definition cache for instant lookup
        foreach ($instance in $scheduleInstances) {
            $roleDefinition = Get-CachedRoleDefinition -RoleId $instance.RoleDefinitionId
            if ($roleDefinition) {
                $expirationTime = $null
                if ($instance.EndDateTime) {
                    $expirationTime = [DateTime]::Parse($instance.EndDateTime).ToLocalTime()
                }
                
                $activeRoles += [PSCustomObject]@{
                    RoleName = $roleDefinition.DisplayName
                    Assignment = $instance
                    ExpirationTime = $expirationTime
                }
            }
        }
    } catch {
        $activeRoles = @()
    }
    
    return $activeRoles
}

function Get-EligibleRolesOptimized {
    param([string]$CurrentUserId)
    
    # Clear schedule instance cache to ensure fresh data
    $script:ScheduleInstanceCache = @{}
    $script:ScheduleInstanceCacheExpiry = (Get-Date).AddSeconds(30)
    
    $allEligibleRoles = @()
    $activeRoleIds = @()
    $pendingRoleIds = @()
    
    try {
        # OPTIMIZED: Sequential API calls (ThreadJob doesn't share Graph context)
        # But role definition lookups are instant from cache
        $eligibilitySchedules = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -Filter "PrincipalId eq '$CurrentUserId'" -All
        $activatedAssignments = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -Filter "PrincipalId eq '$CurrentUserId' and AssignmentType eq 'Activated'" -All -ErrorAction SilentlyContinue
        $allRequests = Get-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -Filter "PrincipalId eq '$CurrentUserId'" -Top 100 -ErrorAction SilentlyContinue
        
        # Process eligibility schedules with cached role definitions (instant lookup)
        foreach ($schedule in $eligibilitySchedules) {
            $roleDef = Get-CachedRoleDefinition -RoleId $schedule.RoleDefinitionId
            if ($roleDef) {
                $allEligibleRoles += [PSCustomObject]@{
                    RoleDefinitionId = $schedule.RoleDefinitionId
                    RoleDefinition   = @{
                        DisplayName = $roleDef.DisplayName
                        Id = $roleDef.Id
                        Description = $roleDef.Description
                    }
                    PrincipalId      = $schedule.PrincipalId
                    DirectoryScopeId = $schedule.DirectoryScopeId
                }
            }
        }
        
        # Process active assignments
        if ($activatedAssignments) {
            $currentTime = Get-Date
            $activeRoleIds = $activatedAssignments | Where-Object {
                $null -ne $_.EndDateTime -and $_.EndDateTime -gt $currentTime
            } | Select-Object -ExpandProperty RoleDefinitionId -Unique
        }
        
        # Process pending requests - use REST API to get PendingApproval requests
        # The PowerShell cmdlet doesn't reliably return PendingApproval status
        try {
            $pendingResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests?`$filter=status eq 'PendingApproval'" -ErrorAction SilentlyContinue
            if ($pendingResponse -and $pendingResponse.value) {
                $pendingRoleIds = @($pendingResponse.value | Where-Object { $_.principalId -eq $CurrentUserId } | Select-Object -ExpandProperty roleDefinitionId -Unique)
            } else {
                $pendingRoleIds = @()
            }
        } catch {
            $pendingRoleIds = @()
        }
    } catch {
        Write-Host "Error retrieving roles: $($_.Exception.Message)" -ForegroundColor Red
        $allEligibleRoles = @()
    }
    
    # Filter out both active and pending roles
    $eligibleRoles = $allEligibleRoles | Where-Object { 
        $activeRoleIds -notcontains $_.RoleDefinitionId -and $pendingRoleIds -notcontains $_.RoleDefinitionId
    }

    # Deduplicate roles by RoleDefinitionId to prevent duplicates
    $validRoles = $eligibleRoles | Sort-Object RoleDefinitionId | Group-Object RoleDefinitionId | ForEach-Object { $_.Group[0] }
    
    return $validRoles
}

# ========================= Help Menu =========================

function Show-HelpMenu {
    [Console]::CursorVisible = $false
    Clear-Host
    Write-Host "[ E N T R A   P I M ]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📖 Help Menu" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SHORTCUTS" -ForegroundColor Yellow
    Write-Host "  ↑/↓ Navigate   SPACE Toggle   Ctrl+A Select All   ENTER Confirm"
    Write-Host "  ESC Cancel     $(Get-QuitShortcutText)    $(Get-HelpShortcutText)"
    Write-Host ""
    Write-Host "WORKFLOWS" -ForegroundColor Yellow
    Write-Host "  Activate Roles     - Request temporary elevated permissions"
    Write-Host "  Deactivate Roles   - End active role sessions early"
    Write-Host ""
    Write-Host "INDICATORS" -ForegroundColor Yellow
    Write-Host "  [✓] Selected   [ ] Not selected   ► Current item"
    Write-Host ""
    Write-Host "NOTES" -ForegroundColor Yellow
    Write-Host "  • Roles must be active 5 min before deactivation"
    Write-Host "  • Minimum activation duration is 5 minutes"
    Write-Host "  • Justification required for all activations"
    Write-Host ""
    Write-Host "Press any key to return..." -ForegroundColor Magenta
    $null = [Console]::ReadKey($true)
}

function Show-DynamicExpirationMenu {
    param(
        [array]$RoleExpirationData,
        [string]$Title
    )
    
    [Console]::CursorVisible = $false
    $currentIndex = 0
    $selected = @()
    for ($i = 0; $i -lt $RoleExpirationData.Count; $i++) {
        $selected += $false
    }
    
    try {
        do {
            Clear-Host
            Show-PIMGlobalHeaderMinimal
            Write-Host ""
            Write-Host $Title -ForegroundColor Cyan
            Write-Host ("=" * $Title.Length) -ForegroundColor Cyan
            Write-Host ""
            
            # Filter out expired roles and check if any remain
            $activeRoleData = @()
            $activeSelected = @()
            
            for ($i = 0; $i -lt $RoleExpirationData.Count; $i++) {
                $roleData = $RoleExpirationData[$i]
                $role = $roleData.Role
                $expirationTime = $roleData.ExpirationTime
                
                # Calculate countdown
                $isExpired = $false
                if ($expirationTime) {
                    $timeRemaining = $expirationTime - (Get-Date)
                    
                    
                    if ($timeRemaining.TotalSeconds -gt 0) {
                        $hours = [Math]::Floor($timeRemaining.TotalHours)
                        $minutes = $timeRemaining.Minutes
                        $seconds = $timeRemaining.Seconds
                        
                        if ($hours -gt 0) {
                            $countdownText = "expires in ${hours}h ${minutes}m ${seconds}s"
                        } else {
                            $countdownText = "expires in ${minutes}m ${seconds}s"
                        }
                    } else {
                        $countdownText = "expired"
                        $isExpired = $true
                    }
                } else {
                    $countdownText = "no expiration data"
                }
                
                # Only include non-expired roles
                if (-not $isExpired) {
                    $activeRoleData += @{
                        Role = $role
                        ExpirationTime = $expirationTime
                        CountdownText = $countdownText
                        OriginalIndex = $i
                    }
                    $activeSelected += $selected[$i]
                }
            }
            
            # Check if all roles expired during countdown
            if ($activeRoleData.Count -eq 0) {
                Clear-Host
                Show-PIMGlobalHeaderMinimal
                Write-Host ""
                Write-Host "ℹ️  No active roles to deactivate at this time." -ForegroundColor Gray
                Write-Host ""
                Write-Host "Would you like to activate roles instead? (Y/N): " -NoNewline -ForegroundColor Cyan
                Write-Host ""
                Write-Host ""
                Write-Host "Ctrl+Q to exit" -ForegroundColor Magenta
                
                # Ask if user wants to manage more roles
                do {
                    [Console]::SetCursorPosition(42, [Console]::CursorTop - 2)
                    [Console]::CursorVisible = $true
                    $userInput = Read-Host
                    $userInput = $userInput.Trim().ToUpper()
                    if ($userInput -eq "Y" -or $userInput -eq "YES") {
                        [Console]::CursorVisible = $true
                        Start-PIMRoleManagement -CurrentUserId $script:CurrentUserId
                        return
                    } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
                        Show-NoWorkflowsAndWaitForExit
                    return
                    } else {
                        Write-Host "Please enter Y or N." -ForegroundColor Yellow
                    }
                } while ($true)
            }
            
            # Update arrays to only include active roles
            $selected = $activeSelected
            if ($currentIndex -ge $activeRoleData.Count) {
                $currentIndex = $activeRoleData.Count - 1
            }
            
            # Display active roles with dynamic countdown
            for ($i = 0; $i -lt $activeRoleData.Count; $i++) {
                $roleInfo = $activeRoleData[$i]
                
                # Display role with selection indicator
                $checkbox = if ($selected[$i]) { "[✓]" } else { "[ ]" }
                $arrow = if ($i -eq $currentIndex) { "► " } else { "  " }
                
                Write-Host "$arrow$checkbox $($roleInfo.Role.RoleName) ($($roleInfo.CountdownText))" -ForegroundColor $(if ($i -eq $currentIndex) { "Yellow" } else { "White" })
            }
            
            Write-Host ""
            $selectedCount = ($selected | Where-Object { $_ }).Count
            Write-Host "Roles Selected: $selectedCount" -ForegroundColor Green
            Write-Host ""
            Write-Host "↑/↓ Navigate | SPACE Toggle | Ctrl+A Select All | ENTER Confirm | $(Get-HelpShortcutText) | $(Get-QuitShortcutText)" -ForegroundColor Magenta
            
            # Handle input with timeout for countdown updates
            $inputAvailable = $false
            $timeout = 1000 # 1 second timeout
            $startTime = Get-Date
            
            while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout -and -not $inputAvailable) {
                if ([Console]::KeyAvailable) {
                    $inputAvailable = $true
                    break
                }
                Start-Sleep -Milliseconds 50
            }
            
            if ($inputAvailable) {
                $key = [Console]::ReadKey($true)
                
                switch ($key.Key) {
                    "UpArrow" {
                        if ($currentIndex -gt 0) { $currentIndex-- }
                    }
                    "DownArrow" {
                        if ($currentIndex -lt ($RoleExpirationData.Count - 1)) { $currentIndex++ }
                    }
                    "Spacebar" {
                        $selected[$currentIndex] = -not $selected[$currentIndex]
                    }
                    "Enter" {
                        $selectedIndices = @()
                        for ($i = 0; $i -lt $selected.Count; $i++) {
                            if ($selected[$i]) {
                                $selectedIndices += $i
                            }
                        }
                        # Clear screen before returning to prevent UI overlap
                        Clear-Host
                        return $selectedIndices
                    }
                    "Escape" {
                        return @()
                    }
                }
                
                # Handle Ctrl+A to select/deselect all
                if ($key.Modifiers -eq "Control" -and $key.Key -eq "A") {
                    # Check if all are currently selected
                    $allSelected = ($selected | Where-Object { $_ -eq $true }).Count -eq $selected.Count
                    # Toggle: if all selected, deselect all; otherwise select all
                    for ($i = 0; $i -lt $selected.Count; $i++) {
                        $selected[$i] = -not $allSelected
                    }
                }
                
                # Handle Ctrl+H for help menu
                if ($key.Modifiers -eq "Control" -and $key.Key -eq "H") {
                    Show-HelpMenu
                }

                # Handle Ctrl+Q
                if ($key.Modifiers -eq "Control" -and $key.Key -eq "Q") {
                    Invoke-PIMExit -Message "Exiting PIM role management..."
                }
            }
            
        } while ($true)
    }
    finally {
        # Keep cursor hidden - calling code manages visibility
    }
}

function Start-RoleDeactivationWorkflowWithCheck {
    param([string]$CurrentUserId)
    
    # Show progress while loading
    Write-Host ""
    Write-Host "🔄 Loading active roles..." -ForegroundColor Cyan -NoNewline
    
    # OPTIMIZED: Get active roles with fast lookup
    $activeRoles = Get-ActiveRolesOptimized -CurrentUserId $CurrentUserId
    Write-Host " ✅ $($activeRoles.Count) found" -ForegroundColor Green
    
    if ($activeRoles.Count -eq 0) {
        Write-Host "ℹ️  No active roles to deactivate at this time." -ForegroundColor Gray
        Write-Host ""
        
        # Ask if user wants to activate roles instead
        $response = Read-PIMInput -Prompt "Would you like to activate roles instead? (Y/N)" -ForegroundColor Cyan
        
        if ($response) {
            $userInput = $response.Trim().ToUpper()
            if ($userInput -eq "Y" -or $userInput -eq "YES") {
                Clear-Host
                Show-PIMGlobalHeaderMinimal
                Write-Host ""
                Write-Host "🔄 Loading eligible roles..." -ForegroundColor Cyan -NoNewline
                $eligibleRoles = Get-EligibleRolesOptimized -CurrentUserId $CurrentUserId
                if ($eligibleRoles.Count -gt 0) {
                    Write-Host " ✅ $($eligibleRoles.Count) found" -ForegroundColor Green
                    Start-RoleActivationWorkflow -ValidRoles $eligibleRoles -CurrentUserId $CurrentUserId
                } else {
                    Write-Host ""
                    Write-Host ""
                    Write-Host "❌ No eligible roles available for activation." -ForegroundColor Red
                }
                return
            } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
                Write-Host ""
                Write-Host "❌ No role management workflows available." -ForegroundColor Red
                Write-Host ""
                Write-Host "Check back later when roles are approved or activated." -ForegroundColor Gray
                Write-Host ""
                Show-DynamicControlBar
                
                # Wait for Ctrl+Q to exit
                do {
                    $key = [Console]::ReadKey($true)
                    if (Test-QuitShortcut -Key $key) {
                        Invoke-PIMExit -Message "Exiting PIM role management..."
                    }
                } while ($true)
            } else {
                Write-Host "Please enter Y or N." -ForegroundColor Yellow
            }
        }
        return
    }
    
    # Continue with deactivation workflow - we already checked for active roles above
    
    # Skip cached schedules - we already have the data from schedule instances above
    # Use the schedule instances we already retrieved for 5-minute checking
    
    # Check for roles that are too new to deactivate (5-minute rule)
    # Use the same logic as smart routing to get accurate activation times
    $readyToDeactivate = @()
    $tooNewRoles = @()
    
    foreach ($role in $activeRoles) {
        try {
            $assignment = $role.Assignment
            $activationTime = $null
            
            # Use individual activation time from API
            if ($assignment.StartDateTime) {
                $activationTime = [DateTime]::Parse($assignment.StartDateTime).ToLocalTime()
            }
            
            if ($activationTime) {
                $timeSinceActivation = (Get-Date) - $activationTime
                
                if ($timeSinceActivation.TotalMinutes -lt 5) {
                    $tooNewRoles += @{
                        RoleName = $role.RoleName
                        ActivationTime = $activationTime
                        Assignment = $role.Assignment
                    }
                } else {
                    $readyToDeactivate += $role
                }
            } else {
                # No activation time available, assume it's ready (old activation)
                $readyToDeactivate += $role
            }
        } catch {
            # If there's an error checking, assume it's ready
            $readyToDeactivate += $role
        }
    }
    
    
    # If some roles are too new, show countdown
    if ($tooNewRoles.Count -gt 0) {
        Clear-Host
        Show-PIMGlobalHeaderMinimal
        Write-Host ""
        
        if ($readyToDeactivate.Count -eq 0) {
            Write-Host "⏰ All roles are within the 5-minute activation period." -ForegroundColor Yellow
            Write-Host "Showing countdown until they can be deactivated..." -ForegroundColor Cyan
        } else {
            Write-Host "⏰ Some roles are within the 5-minute activation period." -ForegroundColor Yellow
            Write-Host "Showing countdown for roles that cannot be deactivated yet..." -ForegroundColor Cyan
        }
        Write-Host ""
        
        $countdownResult = Show-DeactivationCountdown -TooNewRoles $tooNewRoles
        
        # If countdown completed successfully, continue to deactivation workflow
        if ($countdownResult -eq $true) {
            # Refresh and get all active roles now that countdown is complete
            Start-RoleDeactivationWorkflowWithCheck -CurrentUserId $CurrentUserId
            return
        }
        return
    }
    
    # If no roles ready after filtering, show message and continue to deactivation workflow
    if ($readyToDeactivate.Count -eq 0) {
        Write-Host "ℹ️  All roles are within the 5-minute activation period." -ForegroundColor Gray
        Write-Host ""
        
        do {
            Write-Host "Would you like to activate roles instead? (Y/N): " -NoNewline -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Ctrl+Q to exit" -ForegroundColor Magenta
            [Console]::CursorVisible = $true
            $userInput = Read-Host
            $userInput = $userInput.Trim().ToUpper()
            if ($userInput -eq "Y" -or $userInput -eq "YES") {
                Clear-Host
                Start-PIMRoleManagement -CurrentUserId $CurrentUserId
                return
            } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
                Write-Host "No additional roles will be managed." -ForegroundColor Red
                Write-Host "Please close the terminal." -ForegroundColor Yellow
                Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

                # Hide cursor and wait for user to exit with Ctrl+Q
                [Console]::CursorVisible = $false
                do {
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        if (Test-GlobalShortcut -Key $key) {
                            return
                        }
                    }
                    Start-Sleep -Milliseconds 100
                } while ($true)
            } else {
                Write-PIMHost "Please enter Y or N." -ForegroundColor Yellow -ControlsText $script:ControlMessages['Exit']
            }
        } while ($true)
    }
    
    # Use expiration data already collected during initial role retrieval - NO ADDITIONAL API CALLS
    $roleExpirationData = @()
    $filteredReadyToDeactivate = @()
    
    # Process roles using expiration data already available in role objects
    foreach ($role in $readyToDeactivate) {
        # Check if role is already expired using data we already have
        if ($role.ExpirationTime) {
            if ($role.ExpirationTime -gt (Get-Date)) {
                # Role is still active, include it
                $filteredReadyToDeactivate += $role
                $roleExpirationData += [PSCustomObject]@{
                    Role = $role
                    ExpirationTime = $role.ExpirationTime
                }
            }
            # If expired, skip this role entirely
        } else {
            # No expiration data, assume it's still active
            $filteredReadyToDeactivate += $role
            $roleExpirationData += [PSCustomObject]@{
                Role = $role
                ExpirationTime = $null
            }
        }
    }
    
    # Update readyToDeactivate to only include non-expired roles
    $readyToDeactivate = $filteredReadyToDeactivate
    
    # Check if any roles remain after filtering out expired ones
    if ($readyToDeactivate.Count -eq 0) {
        Write-Host "ℹ️  No active roles to deactivate at this time." -ForegroundColor Gray
        Write-Host ""
        
        # Ask if user wants to activate roles instead with inline input handling
        Write-Host "Would you like to activate roles instead? (Y/N): " -NoNewline -ForegroundColor Cyan
        
        # Show cursor for Y/N input
        [Console]::CursorVisible = $true
        
        # Store cursor position for inline input
        $promptLeft = [Console]::CursorLeft
        $promptTop = [Console]::CursorTop
        
        # Show control bar below the prompt with proper spacing
        Write-Host "`n"  # Add blank line after prompt
        Write-Host "Ctrl+Q to exit" -ForegroundColor Magenta
        $script:LastControlBarLine = [Console]::CursorTop - 1
        
        # Return cursor to inline position after the prompt (same line as Y/N question)
        [Console]::SetCursorPosition($promptLeft, $promptTop)
        
        $userInput = ""
        do {
            $key = [Console]::ReadKey($true)
            
            # Check for Ctrl+Q
            if (Test-QuitShortcut -Key $key) {
                Invoke-PIMExit
                return
            }
            
            # Handle Enter key
            if ($key.Key -eq 'Enter') {
                if ($userInput -eq 'Y' -or $userInput -eq 'y') {
                    # Clear the control bar and move cursor to start of that line
                    if ($script:LastControlBarLine -ge 0) {
                        try {
                            [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                            Write-Host (" " * [Console]::WindowWidth) -NoNewline
                            $script:LastControlBarLine = -1
                        } catch { }
                    }
                    Clear-Host
                                        Start-PIMRoleManagement -CurrentUserId $CurrentUserId
                                        return
                } elseif ($userInput -eq 'N' -or $userInput -eq 'n') {
                    Write-Host ""
                    Show-NoWorkflowsAndWaitForExit
                    return
                } else {
                    Write-Host ""
                    Write-Host "Please enter Y or N: " -NoNewline -ForegroundColor Yellow
                    # Clear and redraw control bar for invalid input
                    if ($script:LastControlBarLine -ge 0) {
                        try {
                            [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                            Write-Host (" " * [Console]::WindowWidth) -NoNewline
                        } catch { }
                    }
                    Write-Host ""
                    Write-Host "Ctrl+Q to exit" -ForegroundColor Magenta
                    $script:LastControlBarLine = [Console]::CursorTop - 1
                    # Return cursor to prompt position
                    [Console]::SetCursorPosition([Console]::CursorLeft, [Console]::CursorTop - 2)
                    $userInput = ""
                }
            }
            # Handle backspace
            elseif ($key.Key -eq 'Backspace' -and $userInput.Length -gt 0) {
                $userInput = $userInput.Substring(0, $userInput.Length - 1)
                Write-Host "`b `b" -NoNewline
            }
            # Handle regular characters (Y/N only)
            elseif ($key.KeyChar -match '[YyNn]' -and $userInput.Length -eq 0) {
                $userInput = $key.KeyChar.ToString().ToUpper()
                Write-Host $userInput -NoNewline -ForegroundColor Green
            }
        } while ($true)
        return
    }
    
    # Show dynamic countdown menu
    $selectedIndices = Show-DynamicExpirationMenu -RoleExpirationData $roleExpirationData -Title "🔄 Select Active Roles to Deactivate"
    
    if ($selectedIndices.Count -eq 0) {
                Write-Host "❌ No roles selected for deactivation." -ForegroundColor Yellow
        return
    }
    
    # Clear screen and show clean deactivation progress
    Clear-Host
    Show-PIMGlobalHeaderMinimal
    Write-Host ""
    Write-Host "🔄 Deactivating $($selectedIndices.Count) role(s)..." -ForegroundColor Cyan
    Write-Host ""
    
    $successCount = 0
    $failCount = 0
    $skippedCount = 0
    
    foreach ($index in $selectedIndices) {
        if ($index -lt 0 -or $index -ge $readyToDeactivate.Count) { continue }
        
        $role = $readyToDeactivate[$index]
        $assignment = $role.Assignment
        $roleName = $role.RoleName
        
        if (-not $assignment.PrincipalId -or -not $assignment.RoleDefinitionId) {
            Write-Host "❌ Invalid assignment data for: $roleName" -ForegroundColor Red
            $failCount++
            continue
        }
        
        $deactivationRequest = @{
            action = "selfDeactivate"
            principalId = $assignment.PrincipalId
            roleDefinitionId = $assignment.RoleDefinitionId
            directoryScopeId = if ($assignment.DirectoryScopeId) { $assignment.DirectoryScopeId } else { "/" }
        }
        
        # Sequential with retry logic
        $maxRetries = 3
        $retryCount = 0
        $done = $false
        
        while (-not $done -and $retryCount -lt $maxRetries) {
            try {
                $result = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $deactivationRequest -ErrorAction Stop
                if ($result) {
                    Write-Host "✅ Successfully deactivated: $roleName" -ForegroundColor Green
                    $successCount++
                }
                $done = $true
            } catch {
                $errorMsg = $_.Exception.Message
                if ($errorMsg -like "*RoleAssignmentDoesNotExist*") {
                    if ($retryCount -gt 0) {
                        Write-Host "✅ Successfully deactivated: $roleName (confirmed on retry)" -ForegroundColor Green
                        $successCount++
                    } else {
                        Write-Host "⚠️ Role already deactivated: $roleName" -ForegroundColor Yellow
                        $skippedCount++
                    }
                    $done = $true
                } elseif ($errorMsg -like "*error occurred while sending the request*") {
                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Write-Host "⚠️ Network error, retrying $roleName ($retryCount/$maxRetries)..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 2
                    } else {
                        Write-Host "❌ Failed to deactivate: $roleName after $maxRetries retries" -ForegroundColor Red
                        $failCount++
                        $done = $true
                    }
                } else {
                    Write-Host "❌ Failed to deactivate: $roleName" -ForegroundColor Red
                    $failCount++
                    $done = $true
                }
            }
        }
    }
    
    # Clear cache
    $script:ScheduleInstanceCache = @{}
    $script:ScheduleInstanceCacheExpiry = (Get-Date).AddSeconds(-1)
    $global:ActiveRoleCache = @()
    $global:ActiveRoleCacheTime = $null
    
    Write-Host ""
    
    # Ask if user wants to manage more roles
    do {
        [Console]::CursorVisible = $true
        $userInput = Read-PIMInput -Prompt "Would you like to manage more roles? (Y/N)" -ControlsText $script:ControlMessages['Exit']
        if (-not $userInput) { continue }
        $userInput = $userInput.Trim().ToUpper()
        if ($userInput -eq "Y" -or $userInput -eq "YES") {
            $continueChoice = "Yes"
            break
        } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
            $continueChoice = "No"
            break
        } else {
            Write-Host "Please enter Y or N." -ForegroundColor Yellow
        }
    } while ($true)
    
    if ($continueChoice -eq "Yes") {
        # Return to main workflow selector (Entra/Azure choice)
        return
    } else {
        Write-Host "No additional roles will be managed." -ForegroundColor Red
        Write-Host ""
        Write-Host "Please close the terminal." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

        # Hide cursor and wait for Ctrl+Q to exit
        [Console]::CursorVisible = $false
        do {
            $key = [Console]::ReadKey($true)
            if (Test-QuitShortcut -Key $key) {
                Invoke-PIMExit -Message "Exiting PIM role management..."
            }
        } while ($true)
    }
    
    # Use expiration data already collected during initial role retrieval - NO ADDITIONAL API CALLS
    $roleExpirationData = @()
    $filteredReadyToDeactivate = @()
    
    # Process roles using expiration data already available in role objects
    foreach ($role in $readyToDeactivate) {
        # Check if role is already expired using data we already have
        if ($role.ExpirationTime) {
            if ($role.ExpirationTime -gt (Get-Date)) {
                # Role is still active, include it
                $filteredReadyToDeactivate += $role
                $roleExpirationData += [PSCustomObject]@{
                    Role = $role
                    ExpirationTime = $role.ExpirationTime
                }
            }
            # If expired, skip this role entirely
        } else {
            # No expiration data, assume it's still active
            $filteredReadyToDeactivate += $role
            $roleExpirationData += [PSCustomObject]@{
                Role = $role
                ExpirationTime = $null
            }
        }
    }
    
    # Update readyToDeactivate to only include non-expired roles
    $readyToDeactivate = $filteredReadyToDeactivate
    
    # Check if any roles remain after filtering out expired ones
    if ($readyToDeactivate.Count -eq 0) {
        Write-Host "ℹ️  No active roles to deactivate at this time." -ForegroundColor Gray
        Write-Host ""
        
        # Ask if user wants to activate roles instead with inline input handling
        Write-Host "Would you like to activate roles instead? (Y/N): " -NoNewline -ForegroundColor Cyan
        
        # Show cursor for Y/N input
        [Console]::CursorVisible = $true
        
        # Store cursor position for inline input
        $promptLeft = [Console]::CursorLeft
        $promptTop = [Console]::CursorTop
        
        # Show control bar below the prompt with proper spacing
        Write-Host "`n"  # Add blank line after prompt
        Write-Host "Ctrl+Q to exit" -ForegroundColor Magenta
        $script:LastControlBarLine = [Console]::CursorTop - 1
        
        # Return cursor to inline position after the prompt (same line as Y/N question)
        [Console]::SetCursorPosition($promptLeft, $promptTop)
        
        $userInput = ""
        do {
            $key = [Console]::ReadKey($true)
            
            # Check for Ctrl+Q
            if (Test-QuitShortcut -Key $key) {
                Invoke-PIMExit
                return
            }
            
            # Handle Enter key
            if ($key.Key -eq 'Enter') {
                if ($userInput -eq 'Y' -or $userInput -eq 'y') {
                    # Clear the control bar and move cursor to start of that line
                    if ($script:LastControlBarLine -ge 0) {
                        try {
                            [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                            Write-Host (" " * [Console]::WindowWidth) -NoNewline
                            $script:LastControlBarLine = -1
                        } catch { }
                    }
                    Clear-Host
                                        Start-PIMRoleManagement -CurrentUserId $CurrentUserId
                                        return
                } elseif ($userInput -eq 'N' -or $userInput -eq 'n') {
                    Write-Host ""
                    Show-NoWorkflowsAndWaitForExit
                    return
                } else {
                    Write-Host ""
                    Write-Host "Please enter Y or N: " -NoNewline -ForegroundColor Yellow
                    # Clear and redraw control bar for invalid input
                    if ($script:LastControlBarLine -ge 0) {
                        try {
                            [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                            Write-Host (" " * [Console]::WindowWidth) -NoNewline
                        } catch { }
                    }
                    Write-Host ""
                    Write-Host "Ctrl+Q to exit" -ForegroundColor Magenta
                    $script:LastControlBarLine = [Console]::CursorTop - 1
                    # Return cursor to prompt position
                    [Console]::SetCursorPosition([Console]::CursorLeft, [Console]::CursorTop - 2)
                    $userInput = ""
                }
            }
            # Handle backspace
            elseif ($key.Key -eq 'Backspace' -and $userInput.Length -gt 0) {
                $userInput = $userInput.Substring(0, $userInput.Length - 1)
                Write-Host "`b `b" -NoNewline
            }
            # Handle regular characters (Y/N only)
            elseif ($key.KeyChar -match '[YyNn]' -and $userInput.Length -eq 0) {
                $userInput = $key.KeyChar.ToString().ToUpper()
                Write-Host $userInput -NoNewline -ForegroundColor Green
            }
        } while ($true)
        return
    }
    
    # Show dynamic countdown menu
    $selectedIndices = Show-DynamicExpirationMenu -RoleExpirationData $roleExpirationData -Title "🔄 Select Active Roles to Deactivate"
    
    if ($selectedIndices.Count -eq 0) {
                Write-Host "❌ No roles selected for deactivation." -ForegroundColor Yellow
        return
    }
    
    # Clear screen and show clean deactivation progress
    Clear-Host
    Show-PIMGlobalHeaderMinimal
    Write-Host ""
    Write-Host "🔄 Deactivating $($selectedIndices.Count) role(s)..." -ForegroundColor Cyan
    Write-Host ""
    
    $successCount = 0
    $failCount = 0
    $skippedCount = 0
    
    foreach ($index in $selectedIndices) {
        # Validate index
        if ($index -lt 0 -or $index -ge $readyToDeactivate.Count) {
            Write-Host "⚠️ Invalid selection index: $index" -ForegroundColor Yellow
            continue
        }
        
        $role = $readyToDeactivate[$index]
        $assignment = $role.Assignment
        $roleName = $role.RoleName
        
        try {
            # Validate assignment data
            if (-not $assignment.PrincipalId -or -not $assignment.RoleDefinitionId) {
                Write-Host "   ❌ Invalid assignment data for: $roleName" -ForegroundColor Red
                $failCount++
                continue
            }
            
            # Create deactivation request
            $deactivationRequest = @{
                action = "selfDeactivate"
                principalId = $assignment.PrincipalId
                roleDefinitionId = $assignment.RoleDefinitionId
                directoryScopeId = if ($assignment.DirectoryScopeId) { $assignment.DirectoryScopeId } else { "/" }
            }
            
            # Make the deactivation request with retry logic for network errors
            $maxRetries = 3
            $retryCount = 0
            $deactivationSuccess = $false
            
            while (-not $deactivationSuccess -and $retryCount -lt $maxRetries) {
                try {
                    $result = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $deactivationRequest -ErrorAction Stop
                    $deactivationSuccess = $true
                    
                    if ($result) {
                        Write-Host "✅ Successfully deactivated: $roleName" -ForegroundColor Green
                        $successCount++
                        
                        # Clear cache to ensure fresh data
                        $script:ScheduleInstanceCache = @{}
                        $script:ScheduleInstanceCacheExpiry = (Get-Date).AddSeconds(-1)
                        $global:ActiveRoleCache = @()
                        $global:ActiveRoleCacheTime = $null
                    }
                } catch {
                    $errorMessage = $_.Exception.Message
                    if ($errorMessage -like "*RoleAssignmentDoesNotExist*") {
                        # If we retried due to network error and now it's gone, the first request likely succeeded
                        if ($retryCount -gt 0) {
                            Write-Host "✅ Successfully deactivated: $roleName (confirmed on retry)" -ForegroundColor Green
                            $successCount++
                        } else {
                            Write-Host "⚠️ Role already deactivated: $roleName" -ForegroundColor Yellow
                            $skippedCount++
                        }
                        $deactivationSuccess = $true
                    } elseif ($errorMessage -like "*error occurred while sending the request*") {
                        $retryCount++
                        if ($retryCount -lt $maxRetries) {
                            Write-Host "⚠️ Network error, retrying $roleName ($retryCount/$maxRetries)..." -ForegroundColor Yellow
                            Start-Sleep -Seconds 2
                        } else {
                            Write-Host "❌ Failed to deactivate: $roleName after $maxRetries retries" -ForegroundColor Red
                            $failCount++
                        }
                    } else {
                        Write-Host "❌ Failed to deactivate: $roleName" -ForegroundColor Red
                        $failCount++
                        $deactivationSuccess = $true
                    }
                }
            }
        } catch {
            Write-Host "❌ Failed to deactivate: $roleName" -ForegroundColor Red
            $failCount++
        }
    }
    
    Write-Host ""
    
    # Ask if user wants to manage more roles
    do {
        [Console]::CursorVisible = $true
        $userInput = Read-PIMInput -Prompt "Would you like to manage more roles? (Y/N)" -ControlsText $script:ControlMessages['Exit']
        if (-not $userInput) { continue }
        $userInput = $userInput.Trim().ToUpper()
        if ($userInput -eq "Y" -or $userInput -eq "YES") {
            $continueChoice = "Yes"
            break
        } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
            $continueChoice = "No"
            break
        } else {
            Write-Host "Please enter Y or N." -ForegroundColor Yellow
        }
    } while ($true)
    
    if ($continueChoice -eq "Yes") {
        # Return to main workflow selector (Entra/Azure choice)
        return
    } else {
        Write-Host "No additional roles will be managed." -ForegroundColor Red
        Write-Host ""
        Write-Host "Please close the terminal." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

        # Hide cursor and wait for Ctrl+Q to exit
        [Console]::CursorVisible = $false
        do {
            $key = [Console]::ReadKey($true)
            if (Test-QuitShortcut -Key $key) {
                Invoke-PIMExit -Message "Exiting PIM role management..."
            }
        } while ($true)
    }
}

function Show-PIMGlobalHeader {
        Write-Host "[ E N T R A   P I M ]" -ForegroundColor Cyan
        Write-Host "    with PowerShell" -ForegroundColor DarkGray
    }
    
    function Show-PIMGlobalHeaderMinimal {
        Write-Host "[ E N T R A   P I M ]" -ForegroundColor Cyan
    }
    
    # ========================= Centralized Control Menu System =========================
    
    # Control message constants - dynamically set based on platform
    $helpText = Get-HelpShortcutText
    $exitText = Get-QuitShortcutText
    $script:ControlMessages = @{
        'Exit' = $exitText
        'Navigation' = "↑/↓ Navigate | SPACE Toggle | Ctrl+A Select All | ENTER Confirm | $helpText | $exitText"
        'Input' = "$helpText | $exitText"
        'Menu' = "↑/↓ Navigate | SPACE Toggle | Ctrl+A Select All | ENTER Confirm | $helpText | $exitText"
        'Shortcuts' = "Ctrl+A Select All | Ctrl+D Deselect All | Ctrl+R Refresh"
    }
    
    # Centralized exit handler
    function Invoke-PIMExit {
        param(
            [string]$Message = "Exiting..."
        )
        
        [Console]::CursorVisible = $true
        Clear-Host
        Write-Host $Message -ForegroundColor Yellow
        
        try {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Write-Host "✅ Disconnected from Microsoft Graph." -ForegroundColor Green
        } catch {
            Write-Host "ℹ️ Already disconnected from Microsoft Graph." -ForegroundColor DarkGray
        }
        
        Write-Host "Terminal will close in 2 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        [Environment]::Exit(0)
    }
    
    # Centralized key handler for common shortcuts
    function Test-GlobalShortcut {
        param(
            [System.ConsoleKeyInfo]$Key
        )

        # Handle Ctrl+Q globally
        if ($Key.Key -eq 'Q' -and $Key.Modifiers -eq 'Control') {
            Invoke-PIMExit
            return $true
        }

        return $false
    }
    
    # Enhanced input reader with centralized control handling
    function Read-PIMInput {
        param(
            [string]$Prompt,
            [string]$ControlsText = $script:ControlMessages['Input'],
            [switch]$Required,
            [string]$ValidationPattern,
            [string]$ValidationMessage
        )
        
        # Show cursor for input
        [Console]::CursorVisible = $true
        
        # Display prompt with colon and space, keep cursor inline
        Write-Host "${Prompt}: " -ForegroundColor Cyan -NoNewline
        
        # Store cursor position for inline input
        $promptLeft = [Console]::CursorLeft
        $promptTop = [Console]::CursorTop
        
        # Show control bar below the prompt
        Write-Host ""  # Move to next line
        Write-Host ""  # Add extra space
        Write-Host $ControlsText -ForegroundColor Magenta
        $script:LastControlBarLine = [Console]::CursorTop - 1
        
        # Return cursor to inline position after the prompt
        [Console]::SetCursorPosition($promptLeft, $promptTop)
        
        $userInput = ""
        do {
            $key = [Console]::ReadKey($true)
            
            # Check global shortcuts first
            if (Test-GlobalShortcut -Key $key) {
                return $null
            }

            # Handle Ctrl+H for help
            if (Test-HelpShortcut -Key $key) {
                Show-HelpMenu
                # Redraw the prompt after help
                Clear-Host
                if ($script:CurrentWorkflow -eq 'Azure') {
                    Show-AzurePIMHeader
                } else {
                    Show-PIMGlobalHeaderMinimal
                }
                Write-Host ""
                Write-Host "${Prompt}: " -ForegroundColor Cyan -NoNewline
                Write-Host $userInput -NoNewline -ForegroundColor White
                $promptLeft = [Console]::CursorLeft
                $promptTop = [Console]::CursorTop
                Write-Host ""
                Write-Host ""
                Write-Host $ControlsText -ForegroundColor Magenta
                $script:LastControlBarLine = [Console]::CursorTop - 1
                [Console]::SetCursorPosition($promptLeft, $promptTop)
                continue
            }

            # Handle ESC for cancellation
            if ($key.Key -eq 'Escape') {
                Write-Host ""
                return $null
            }
            
            # Handle Enter
            if ($key.Key -eq 'Enter') {
                # Store current position (after user input on prompt line)
                $inputEndTop = $promptTop + 1
                
                # Clear the control bar and any leftover content below it
                if ($script:LastControlBarLine -ge 0) {
                    try {
                        # Clear control bar line and several lines below to remove stale content
                        for ($clearLine = $script:LastControlBarLine; $clearLine -lt [Math]::Min($script:LastControlBarLine + 5, [Console]::BufferHeight); $clearLine++) {
                            [Console]::SetCursorPosition(0, $clearLine)
                            Write-Host (" " * [Console]::WindowWidth) -NoNewline
                        }
                        $script:LastControlBarLine = -1
                    } catch { }
                }
                
                # Move cursor to line after the prompt for subsequent output
                [Console]::SetCursorPosition(0, $inputEndTop)
                break
            }
            
            # Handle Backspace
            if ($key.Key -eq 'Backspace' -and $userInput.Length -gt 0) {
                $userInput = $userInput.Substring(0, $userInput.Length - 1)
                Write-Host "`b `b" -NoNewline
            }
            
            # Handle regular characters
            elseif ($key.KeyChar -ne "`0" -and [char]::IsControl($key.KeyChar) -eq $false) {
                $userInput += $key.KeyChar
                Write-Host $key.KeyChar -NoNewline -ForegroundColor White
            }
        } while ($true)
        
        # Validate input if required
        if ($Required -and [string]::IsNullOrWhiteSpace($userInput)) {
            Write-Host "Input is required." -ForegroundColor DarkRed
            return Read-PIMInput -Prompt $Prompt -ControlsText $ControlsText -Required:$Required -ValidationPattern $ValidationPattern -ValidationMessage $ValidationMessage
        }
        
        if ($ValidationPattern -and $userInput -notmatch $ValidationPattern) {
            Write-Host $ValidationMessage -ForegroundColor DarkRed
            return Read-PIMInput -Prompt $Prompt -ControlsText $ControlsText -Required:$Required -ValidationPattern $ValidationPattern -ValidationMessage $ValidationMessage
        }
        
        return $userInput
    }
    
    # Dynamic Control Bar System
    $script:LastControlBarLine = -1
    
    function Show-DynamicControlBar {
        param(
            [string]$ControlsText = $script:ControlMessages['Exit'],
            [switch]$Force
        )
    
        # Get current cursor position
        $currentLeft = [Console]::CursorLeft
        $currentTop = [Console]::CursorTop
        
        # Calculate target line (one line below current content for dynamic movement)
        $targetTop = $currentTop + 1
        
        # Clear previous control bar if it exists
        if ($script:LastControlBarLine -ge 0 -and ($script:LastControlBarLine -ne $targetTop -or $Force)) {
            try {
                [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                Write-Host (" " * [Console]::WindowWidth) -NoNewline
            } catch {
                # Ignore if we can't clear the old line
            }
        }
        
        # Ensure buffer is tall enough
        if ($targetTop -ge [Console]::BufferHeight) {
            [Console]::BufferHeight = $targetTop + 1
        }
        
        # Draw the new control bar
        try {
            [Console]::SetCursorPosition(0, $targetTop)
            Write-Host $ControlsText -ForegroundColor Magenta
            
            # Update last control bar line
            $script:LastControlBarLine = $targetTop
            
            # Don't move cursor - let calling function handle positioning
        } catch {
            # Fallback to original position if something goes wrong
            try {
                [Console]::SetCursorPosition($currentLeft, $currentTop)
            } catch {
                # If all else fails, just continue
            }
        }
    }
    
    # Enhanced Write-Host wrapper that updates control bar
    function Write-PIMHost {
        param(
            [string]$Object = "",
            [ConsoleColor]$ForegroundColor = [Console]::ForegroundColor,
            [ConsoleColor]$BackgroundColor = [Console]::BackgroundColor,
            [switch]$NoNewline,
            [string]$ControlsText = $null
        )
        
        Write-Host $Object -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -NoNewline:$NoNewline
        
        # Only show control bar when explicitly requested
        if ($ControlsText) {
            Show-DynamicControlBar -ControlsText $ControlsText
        }
    }
    
    # NOTE: Module loading moved to main execution block at end of script
    
    # ========================= ACTIVATION WORKFLOW =========================
    function Start-RoleActivationWorkflow {
        param(
            [array]$ValidRoles,
            [string]$CurrentUserId
        )
        
        if ($ValidRoles.Count -eq 0) {
            # Clear any existing control bar first
            if ($script:LastControlBarLine -ge 0) {
                try {
                    [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                    Write-Host (" " * [Console]::WindowWidth) -NoNewline
                    $script:LastControlBarLine = -1
                } catch { }
            }
            
            Write-PIMHost "❌ No eligible roles available for activation." -ForegroundColor Red
            Write-PIMHost ""
            Write-PIMHost "Would you like to deactivate roles instead? (Y/N): " -NoNewline -ForegroundColor Cyan
            
            # Show cursor for Y/N input
            [Console]::CursorVisible = $true
            
            # Store cursor position for inline input
            $promptLeft = [Console]::CursorLeft
            $promptTop = [Console]::CursorTop
            
            # Show control bar below the prompt with proper spacing
            Write-PIMHost "`n"  # Add blank line after prompt
            Write-PIMHost "Y/N to choose | $(Get-QuitShortcutText)" -ForegroundColor Magenta
            $script:LastControlBarLine = [Console]::CursorTop - 1
            
            # Return cursor to inline position after the prompt (same line as Y/N question)
            [Console]::SetCursorPosition($promptLeft, $promptTop)
            
            $userInput = ""
            do {
                $key = [Console]::ReadKey($true)
                
                # Check for Ctrl+Q
                if (Test-QuitShortcut -Key $key) {
                    Invoke-PIMExit
                    return
                }
                
                # Handle Enter key
                if ($key.Key -eq 'Enter') {
                    if ($userInput -eq 'Y' -or $userInput -eq 'y') {
                        # Clear the control bar and move cursor to start of that line
                        if ($script:LastControlBarLine -ge 0) {
                            try {
                                [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                                Write-Host (" " * [Console]::WindowWidth) -NoNewline
                                [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                                $script:LastControlBarLine = -1
                            } catch { }
                        }
                        # Get active roles using cached approach to avoid duplicate API calls
                        $scheduleInstances = Get-CachedScheduleInstances -CurrentUserId $CurrentUserId
                        $activeRoles = @()
                        foreach ($instance in $scheduleInstances) {
                            $roleDefinition = Get-CachedRoleDefinition -RoleId $instance.RoleDefinitionId
                            if ($roleDefinition) {
                                $activeRoles += [PSCustomObject]@{
                                    RoleName = $roleDefinition.DisplayName
                                    Assignment = $instance
                                }
                            }
                        }
                        if ($activeRoles.Count -gt 0) {
                            Start-RoleDeactivationWorkflowWithCheck -CurrentUserId $CurrentUserId
                        } else {
                            Write-Host "❌ No active roles available for deactivation." -ForegroundColor Red
                            Write-Host ""
                            Write-Host "❌ No role management workflows available." -ForegroundColor Yellow
                            Write-Host ""
                            Write-Host "Check back later when roles are approved or activated." -ForegroundColor White
                            Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta
                            
                            # Hide cursor since no input is needed
                            [Console]::CursorVisible = $false
                            
                            # Control bar already shown above, no need for dynamic control bar
                            
                            # Wait for user to exit with Ctrl+Q
                            do {
                                if ([Console]::KeyAvailable) {
                                    $key = [Console]::ReadKey($true)
                                    if (Test-QuitShortcut -Key $key) {
                                        Invoke-PIMExit
                                        return
                                    }
                                }
                                Start-Sleep -Milliseconds 100
                            } while ($true)
                        }
                        return
                    } elseif ($userInput -eq 'N' -or $userInput -eq 'n') {
                        # Clear the control bar and move cursor to start of that line
                        if ($script:LastControlBarLine -ge 0) {
                            try {
                                [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                                Write-Host (" " * [Console]::WindowWidth) -NoNewline
                                [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                                $script:LastControlBarLine = -1
                            } catch { }
                        }
                        Write-Host "✅ No additional role management tasks available." -ForegroundColor Green
                        Write-Host ""
                        Write-Host "All eligible roles are currently activated." -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta
                        
                        # Hide cursor since no input is needed
                        [Console]::CursorVisible = $false
                        
                        # Wait for user to exit with Ctrl+Q
                        do {
                            if ([Console]::KeyAvailable) {
                                $key = [Console]::ReadKey($true)
                                if (Test-QuitShortcut -Key $key) {
                                    Invoke-PIMExit
                                    return
                                }
                            }
                            Start-Sleep -Milliseconds 100
                        } while ($true)
                        return
                    } else {
                        Write-Host ""
                        Write-Host "Please enter Y or N: " -NoNewline -ForegroundColor Yellow
                        # Clear and redraw control bar for invalid input
                        if ($script:LastControlBarLine -ge 0) {
                            try {
                                [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                                Write-Host (" " * [Console]::WindowWidth) -NoNewline
                            } catch { }
                        }
                        Write-Host ""
                        Write-Host "Y/N to choose | $(Get-QuitShortcutText)" -ForegroundColor Magenta
                        $script:LastControlBarLine = [Console]::CursorTop - 1
                        # Return cursor to prompt position
                        [Console]::SetCursorPosition([Console]::CursorLeft, [Console]::CursorTop - 2)
                        $userInput = ""
                    }
                }
                # Handle backspace
                elseif ($key.Key -eq 'Backspace' -and $userInput.Length -gt 0) {
                    $userInput = $userInput.Substring(0, $userInput.Length - 1)
                    Write-Host "`b `b" -NoNewline
                }
                # Handle regular characters (Y/N only)
                elseif ($key.KeyChar -match '[YyNn]' -and $userInput.Length -eq 0) {
                    $userInput = $key.KeyChar.ToString().ToUpper()
                    Write-Host $userInput -NoNewline -ForegroundColor Green
                }
            } while ($true)
        }
        
        # Prepare roles for display
        $roleItems = @()
        foreach ($role in $ValidRoles) {
            $scopeDisplay = ""
            $roleItems += "$($role.RoleDefinition.DisplayName)$scopeDisplay"
        }
        
        # Main workflow loop for role selection and activation
        do {
            # Show checkbox menu for role selection
            $selectedIndices = Show-CheckboxMenu -Items $roleItems -Title "Select Roles to Activate" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:"
            
            if ($selectedIndices.Count -eq 0) {
                Write-Host "❌ No roles selected for activation." -ForegroundColor Yellow
                return
            }
            
            Clear-ConsoleBuffer
        
            # Duration input - add to existing display
            do {
                $durationInput = Read-PIMInput -Prompt "Enter activation duration (e.g., 1H, 30M, 2H30M)" -ControlsText $script:ControlMessages['Input']
                
                if ([string]::IsNullOrWhiteSpace($durationInput) -or $durationInput -notmatch '^\d+[HM]') {
                    Write-Host "ERROR: Invalid format. Use '1H', '30M', or '2H30M'." -ForegroundColor Red
                }
            } while ([string]::IsNullOrWhiteSpace($durationInput) -or $durationInput -notmatch '^\d+[HM]')
            
            # Convert duration to ISO 8601 format and validate minimum 5 minutes
            $duration = $durationInput.ToUpper() -replace '(\d+)H', 'PT${1}H' -replace '(\d+)M', '${1}M'
            if ($duration -match '^\d+M$') { $duration = "PT$duration" }
            
            # Parse duration to check if it's less than 5 minutes
            $totalMinutes = 0
            if ($durationInput.ToUpper() -match '(\d+)H') { $totalMinutes += [int]$matches[1] * 60 }
            if ($durationInput.ToUpper() -match '(\d+)M') { $totalMinutes += [int]$matches[1] }
            
            if ($totalMinutes -lt 5) {
                Write-Host ""
                Write-Host "❌ Activation Duration too short: Minimum Required is 5 minutes." -ForegroundColor Red
                Write-Host ""
                Write-Host "Press any key to return to role selection..." -ForegroundColor Yellow
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Clear-Host
                Show-PIMGlobalHeaderMinimal
                Write-Host ""
                continue  # Restart the role selection loop
            }
            
            # If we get here, validation passed - break out of the loop
            break
            
        } while ($true)
    
        # Justification input
        $justification = Read-PIMInput -Prompt "Enter reason for activation" -ControlsText $script:ControlMessages['Input']
        
        if ([string]::IsNullOrWhiteSpace($justification)) {
            Write-Host "Justification is required." -ForegroundColor Red
            return
        }
        
        Write-Host "🔄 Activating $($selectedIndices.Count) role(s)..." -ForegroundColor Cyan
        
        $successCount = 0
        $failCount = 0
        
        foreach ($index in $selectedIndices) {
            $role = $ValidRoles[$index]
            $roleName = $role.RoleDefinition.DisplayName
            
            $activationRequest = @{
                action = "selfActivate"
                principalId = $CurrentUserId
                roleDefinitionId = $role.RoleDefinitionId
                directoryScopeId = $role.DirectoryScopeId
                justification = $justification
                scheduleInfo = @{
                    startDateTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    expiration = @{
                        type = "afterDuration"
                        duration = $duration
                    }
                }
            }
            
            # Retry logic for network errors
            $maxRetries = 3
            $retryCount = 0
            $done = $false
            
            while (-not $done -and $retryCount -lt $maxRetries) {
                try {
                    $result = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $activationRequest -ErrorAction Stop
                    if ($result) {
                        # Check the status - PendingApproval means it needs approval, Provisioned/Granted means success
                        if ($result.Status -eq "PendingApproval") {
                            Write-Host "⏳ Role activation submitted for: $roleName (pending approval)" -ForegroundColor Yellow
                        } else {
                            Write-Host "✅ Role activation submitted for: $roleName" -ForegroundColor Green
                        }
                        $successCount++
                    }
                    $done = $true
                } catch {
                    $errorMsg = $_.Exception.Message
                    if ($errorMsg -like "*RoleAssignmentExists*") {
                        # If we retried and now it exists, the first request likely succeeded
                        if ($retryCount -gt 0) {
                            Write-Host "✅ Role activation submitted for: $roleName (confirmed on retry)" -ForegroundColor Green
                            $successCount++
                        } else {
                            Write-Host "⚠️ Skipped $roleName - role is already active" -ForegroundColor Yellow
                        }
                        $done = $true
                    } elseif ($errorMsg -like "*PendingRoleAssignmentRequest*") {
                        # Role has a pending activation request in the system - skip it
                        Write-Host "⚠️ Skipped $roleName - a pending request already exists" -ForegroundColor Yellow
                        $done = $true
                    } elseif ($errorMsg -like "*RoleAssignmentRequestAcrsValidationFailed*" -or $errorMsg -like "*&claims=*") {
                        # Conditional Access requires step-up authentication (ACRS claim)
                        Write-Host "🔐 $roleName requires additional authentication (Conditional Access)..." -ForegroundColor Yellow
                        
                        # Extract claims from error message
                        $claimsMatch = [regex]::Match($errorMsg, '&claims=([^&\s\]]+)')
                        if ($claimsMatch.Success) {
                            $encodedClaims = $claimsMatch.Groups[1].Value
                            $decodedClaims = [System.Web.HttpUtility]::UrlDecode($encodedClaims)
                            
                            try {
                                # Get new token with claims challenge
                                $scopes = @('RoleManagement.ReadWrite.Directory', 'Directory.Read.All')
                                $newToken = Get-BrowserAccessTokenWithClaims -Scopes $scopes -Claims $decodedClaims
                                
                                if ($newToken) {
                                    # Reconnect to Graph with new token
                                    $secureToken = ConvertTo-SecureString $newToken -AsPlainText -Force
                                    Connect-MgGraph -AccessToken $secureToken -NoWelcome -ErrorAction Stop
                                    
                                    # Retry the activation request
                                    $result = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $activationRequest -ErrorAction Stop
                                    if ($result) {
                                        Write-Host "✅ Role activation submitted for: $roleName" -ForegroundColor Green
                                        $successCount++
                                    }
                                } else {
                                    Write-Host "❌ Failed to activate: $roleName - Step-up authentication failed" -ForegroundColor Red
                                    $failCount++
                                }
                            } catch {
                                Write-Host "❌ Failed to activate: $roleName - $($_.Exception.Message)" -ForegroundColor Red
                                $failCount++
                            }
                        } else {
                            Write-Host "❌ Failed to activate: $roleName - Could not extract claims from error" -ForegroundColor Red
                            $failCount++
                        }
                        $done = $true
                    } elseif ($errorMsg -like "*error occurred while sending the request*") {
                        $retryCount++
                        if ($retryCount -lt $maxRetries) {
                            Write-Host "⚠️ Network error, retrying $roleName ($retryCount/$maxRetries)..." -ForegroundColor Yellow
                            Start-Sleep -Seconds 2
                        } else {
                            Write-Host "❌ Failed to activate: $roleName after $maxRetries retries" -ForegroundColor Red
                            $failCount++
                            $done = $true
                        }
                    } else {
                        Write-Host "❌ Failed to activate: $roleName - $errorMsg" -ForegroundColor Red
                        $failCount++
                        $done = $true
                    }
                }
            }
        }
        
        Write-Host ""
        
        # Ask if user wants to manage more roles
        do {
            [Console]::CursorVisible = $true
            $userInput = Read-PIMInput -Prompt "Would you like to manage more roles? (Y/N)" -ControlsText $script:ControlMessages['Exit']
            if (-not $userInput) { continue }
            $userInput = $userInput.Trim().ToUpper()
            if ($userInput -eq "Y" -or $userInput -eq "YES") {
                $continueChoice = "Yes"
                break
            } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
                $continueChoice = "No"
                break
            } else {
                Write-Host "Please enter Y or N." -ForegroundColor Yellow
            }
        } while ($true)
        
        if ($continueChoice -eq "Yes") {
            # Return to main workflow selector (Entra/Azure choice)
            return
        } else {
            Write-Host "No additional roles will be managed." -ForegroundColor Red
            Write-Host ""
            Write-Host "Please close the terminal." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

            # Hide cursor and wait for user to exit with Ctrl+Q
            [Console]::CursorVisible = $false
            do {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if (Test-GlobalShortcut -Key $key) {
                        return
                    }
                }
                Start-Sleep -Milliseconds 100
            } while ($true)
        }
    }

    # ========================= Performance Optimization: API Caching =========================
    # Force clear all existing cache
    $global:CachedSchedules = $null
    $global:CachedSchedulesTime = $null
    $global:CachedRoleDefinitions = @{}
    $global:CacheExpiryMinutes = 0  # Force fresh data every time
    
    # Clear any existing cache from previous runs
    Remove-Variable -Name "CachedSchedules" -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name "CachedSchedulesTime" -Scope Global -ErrorAction SilentlyContinue
    
    # Advanced: Pre-computed string formatting cache
    $global:TimeFormatCache = @{}
    function Get-CachedTimeFormat {
        param([TimeSpan]$TimeSpan)
        
        $totalSeconds = [int]$TimeSpan.TotalSeconds
        
        if ($global:TimeFormatCache.ContainsKey($totalSeconds)) {
            return $global:TimeFormatCache[$totalSeconds]
        }
        
        $hours = [int][math]::Floor($TimeSpan.TotalHours)
        $minutes = [int][math]::Floor($TimeSpan.TotalMinutes % 60)
        $seconds = [int][math]::Floor($TimeSpan.TotalSeconds % 60)
        
        $formatted = "{0:D2}:{1:D2}:{2:D2}" -f $hours, $minutes, $seconds
        
        # Cache for future use (limit cache size to prevent memory bloat)
        if ($global:TimeFormatCache.Count -lt 1000) {
            $global:TimeFormatCache[$totalSeconds] = $formatted
        }
        
        return $formatted
    }
    
    # Advanced: Smart UI updates with change detection
    $global:LastUIState = @{}
    function Update-UIIfChanged {
        param(
            [string]$Key,
            [string]$NewContent,
            [int]$Line,
            [ConsoleColor]$Color = "White"
        )
        
        if ($global:LastUIState[$Key] -ne $NewContent) {
            [Console]::SetCursorPosition(0, $Line)
            Write-Host $NewContent.PadRight([Console]::WindowWidth - 1) -ForegroundColor $Color
            $global:LastUIState[$Key] = $NewContent
            Add-PerformanceMetric -Type "UIUpdates"
            return $true  # Changed
        }
        Add-PerformanceMetric -Type "UISkipped"
        return $false  # No change
    }
    
    # Advanced: Memory optimization
    function Optimize-Memory {
        # Force garbage collection for better performance
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        
        # Clear time format cache if it gets too large
        if ($global:TimeFormatCache.Count -gt 500) {
            $global:TimeFormatCache.Clear()
        }
        
        # Clear UI state cache periodically
        if ($global:LastUIState.Count -gt 100) {
            $global:LastUIState.Clear()
        }
    }
    
    # Advanced: Async operations for background processing
    function Start-AsyncOperation {
        param(
            [scriptblock]$Operation,
            [string]$Name = "AsyncOp",
            [hashtable]$Parameters = @{}
        )
        
        # PowerShell 7+ job-based async simulation
        $job = Start-Job -ScriptBlock $Operation -ArgumentList $Parameters -Name $Name
        return $job
    }
    
    # Advanced: Predictive caching based on usage patterns
    $global:AccessPatterns = @{}
    $global:PredictiveCache = @{}
    
    function Update-DataAccessPattern {
        param([string]$Key, [string]$Operation = "read")
        
        if (-not $global:AccessPatterns.ContainsKey($Key)) {
            $global:AccessPatterns[$Key] = @{
                Count = 0
                LastAccessed = Get-Date
                AccessTimes = @()
                Operations = @()
            }
        }
        
        $pattern = $global:AccessPatterns[$Key]
        $pattern.Count++
        $pattern.LastAccessed = Get-Date
        $pattern.AccessTimes += Get-Date
        $pattern.Operations += $Operation
        
        # Keep only last 10 access times to prevent memory bloat
        if ($pattern.AccessTimes.Count -gt 10) {
            $pattern.AccessTimes = $pattern.AccessTimes[-10..-1]
            $pattern.Operations = $pattern.Operations[-10..-1]
        }
    }
    
    function Get-PredictiveCacheKeys {
        # Return keys that are likely to be accessed soon based on patterns
        $hotKeys = $global:AccessPatterns.Keys | Where-Object {
            $pattern = $global:AccessPatterns[$_]
            $pattern.Count -gt 2 -and
            ((Get-Date) - $pattern.LastAccessed).TotalMinutes -lt 15
        } | Sort-Object { $global:AccessPatterns[$_].Count } -Descending
        
        return $hotKeys | Select-Object -First 5
    }
    
    function Start-PredictivePreload {
        # Background job to preload likely-needed data
        $predictiveKeys = Get-PredictiveCacheKeys
        
        foreach ($key in $predictiveKeys) {
            if (-not $global:PredictiveCache.ContainsKey($key)) {
                # Start async preload based on key pattern
                if ($key -match "schedule") {
                    $job = Start-AsyncOperation -Name "Preload_$key" -Operation {
                        # Preload schedule data
                        try {
                            Get-MgRoleManagementDirectoryRoleAssignmentSchedule -All | Select-Object -First 50
                        } catch { $null }
                    }
                    $global:PredictiveCache[$key] = @{ Job = $job; StartTime = Get-Date }
                }
            }
        }
        
        # Clean up old preload jobs
        $expiredKeys = $global:PredictiveCache.Keys | Where-Object {
            ((Get-Date) - $global:PredictiveCache[$_].StartTime).TotalMinutes -gt 5
        }
        foreach ($key in $expiredKeys) {
            if ($global:PredictiveCache[$key].Job) {
                Stop-Job $global:PredictiveCache[$key].Job -ErrorAction SilentlyContinue
                Remove-Job $global:PredictiveCache[$key].Job -ErrorAction SilentlyContinue
            }
            $global:PredictiveCache.Remove($key)
        }
    }
    
    # Advanced: Performance monitoring and metrics
    $global:PerformanceMetrics = @{
        APICallCount = 0
        CacheHits = 0
        CacheMisses = 0
        BatchedCalls = 0
        IndividualCalls = 0
        StartTime = Get-Date
        UIUpdates = 0
        UISkipped = 0
    }
    
    function Add-PerformanceMetric {
        param([string]$Type, [int]$Count = 1)
        
        if ($global:PerformanceMetrics.ContainsKey($Type)) {
            $global:PerformanceMetrics[$Type] += $Count
        }
    }
    
    function Get-CachedSchedules {
        param([string]$CurrentUserId)
        
        Update-DataAccessPattern -Key "schedules" -Operation "read"
        
        # FORCE FRESH DATA - NO CACHING
        Add-PerformanceMetric -Type "CacheMisses"
        
        # Always fetch fresh data - no cache check - MATCH PROGRESS.PS1 EXACTLY
        try {
            Add-PerformanceMetric -Type "APICallCount"
            # Get schedule requests (for activation timestamps) instead of just schedules - OPTIMIZED
            $freshSchedules = Get-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -Filter "PrincipalId eq '$CurrentUserId'" -Top 50
            
            # Return fresh data without caching
            return $freshSchedules
        } catch {
            Write-Host "⚠️ Filter not supported, falling back to full fetch..." -ForegroundColor Yellow
            # Fallback to original method if filter not supported - EXACT MATCH TO PROGRESS.PS1
            $freshSchedules = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -All | Where-Object { 
                $_.PrincipalId -eq $CurrentUserId 
            }
            return $freshSchedules
        }
    }
    
    function Clear-ConsoleBuffer {
        while ([Console]::KeyAvailable) {
            [Console]::ReadKey($true) | Out-Null
        }
    }
    
    function Show-CheckboxMenuWithLiveCountdown {
        param(
            [array]$Items,
            [array]$ActiveRoles,
            [string]$Title = "Select Items",
            [string]$Prompt = "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:"
        )
        
             if ($Items.Count -eq 0) {
             Write-Host "No items to select from." -ForegroundColor Red
             return @()
         }
         
         # Clear screen and show header
        Clear-Host
        Write-Host "[ E N T R A   P I M ]" -ForegroundColor DarkMagenta
        Write-Host "PIM-Global Self-Activate - Automate Self-Activating PIM Roles via Microsoft Entra ID" -ForegroundColor Green
        
        # Initialize selection state
        $selected = @{}
        $currentIndex = 0
        
        # Get cached schedules once
        $cachedSchedules = Get-CachedSchedules -CurrentUserId $currentUserId
        
        # ULTRA AGGRESSIVE DEDUPLICATION: Force only ONE entry per role name at input level
        $uniqueActiveRoles = @()
        $inputDedupTable = @{}
        
        foreach ($role in $ActiveRoles) {
            $roleName = $role.RoleName
            if (-not $inputDedupTable.ContainsKey($roleName)) {
                $inputDedupTable[$roleName] = $role
                $uniqueActiveRoles += $role
            }
            # Skip any additional entries with the same role name
        }
        
        # Process unique roles in parallel (PowerShell 7+ feature)
        $roleExpirationData = $uniqueActiveRoles | ForEach-Object -Parallel {
            $entry = $_
            $schedules = $using:cachedSchedules
            
            try {
                $roleSchedules = $schedules | Where-Object { 
                    $_.PrincipalId -eq $entry.Assignment.PrincipalId -and 
                    $_.RoleDefinitionId -eq $entry.Assignment.RoleDefinitionId 
                }
                
                $schedule = $roleSchedules | Sort-Object CreatedDateTime -Descending | Select-Object -First 1
                
                if ($schedule.ScheduleInfo.Expiration.EndDateTime) {
                    $expirationTime = [DateTime]::Parse($schedule.ScheduleInfo.Expiration.EndDateTime).ToLocalTime()
                    
                    [PSCustomObject]@{
                        RoleName = $entry.RoleName
                        ExpirationTime = $expirationTime
                    }
                }
            } catch {
                # Skip roles we can't get expiration info for
                $null
            }
        } -ThrottleLimit 5 | Where-Object { $_ }
        
        # FINAL DEDUPLICATION: Use Select-Object with unique role names only
        $roleExpirationData = $roleExpirationData | Sort-Object RoleName, ExpirationTime -Descending | Group-Object RoleName | ForEach-Object { $_.Group[0] }
        # Show countdown header immediately after main header
        Write-Host "🕐 Countdown Until Role Expiration" -ForegroundColor Cyan
        # Store initial countdown positions - start at line 4 (after header, space, and countdown title)
        $countdownStartLine = 4
        # Calculate menu positions after countdown display (1 line per role + space + space before menu)
        $menuStartLine = $countdownStartLine + $roleExpirationData.Count + 2  # 1 line per role + space + title
        $statusLine = $menuStartLine + $Items.Count + 1  # After all menu items + 1 space
        # Clear any previous countdown display remnants
        for ($i = 0; $i -lt 10; $i++) {
            [Console]::SetCursorPosition(0, $countdownStartLine + $i)
            Write-Host (" " * [Console]::WindowWidth)
        }
        [Console]::SetCursorPosition(0, $countdownStartLine)
        
        # Force cursor to correct position after countdown header
        
        # Reserve space for countdown display (will be handled by live update loop) - 1 line per role
        foreach ($roleData in $roleExpirationData) {
            Write-Host ""  # Role line only
        }
        Write-Host $Title -ForegroundColor Cyan
        
        # Recalculate positions after initial display
        $menuStartLine = [Console]::CursorTop
        $statusLine = $menuStartLine + $Items.Count + 1
        
        # Show bottom controls once
        Show-BottomControls -ControlsText $script:ControlMessages['Menu'] -ShortcutsText $script:ControlMessages['Shortcuts']
        
        # Hide cursor for cleaner display
        [Console]::CursorVisible = $false
        
        $lastUpdate = Get-Date
        
        try {
            do {
                $currentTime = Get-Date
                
                # Update countdown every second for real-time accuracy
                if (($currentTime - $lastUpdate).TotalSeconds -ge 1) {
                    # Always redraw header at top to ensure it's visible
                    [Console]::SetCursorPosition(0, 0)
                    Write-Host "[ E N T R A   P I M ]" -ForegroundColor DarkMagenta
                    [Console]::SetCursorPosition(0, 1)
                    Write-Host ""  # Space between PIM-Global and Countdown
                    [Console]::SetCursorPosition(0, 2)
                    Write-Host "🕐 Countdown Until Role Expiration" -ForegroundColor Cyan
                    
                    $lineIndex = $countdownStartLine
                    
                    foreach ($roleData in $roleExpirationData) {
                        $timeRemaining = $roleData.ExpirationTime - $currentTime
                        
                        [Console]::SetCursorPosition(0, $lineIndex)
                        
                        if ($timeRemaining.TotalSeconds -gt 0) {
                            $timeDisplay = Get-CachedTimeFormat -TimeSpan $timeRemaining
                            
                            # Color coding based on time remaining
                            if ($timeRemaining.TotalMinutes -le 10) {
                                $icon = "🚨"
                                $color = "Red"
                            } elseif ($timeRemaining.TotalMinutes -le 30) {
                                $icon = "⚠️"
                                $color = "Yellow"
            } else {
                                $icon = "⏳"
                                $color = "Green"
                            }
                            
                            $roleText = "$icon $($roleData.RoleName): $timeDisplay remaining"
                            Update-UIIfChanged -Key "role_$($roleData.RoleName)" -NewContent $roleText -Line $lineIndex -Color $color
                            } else {
                            $roleText = "❌ $($roleData.RoleName): Expired"
                            Write-Host $roleText.PadRight([Console]::WindowWidth - 1) -ForegroundColor Red
                        }
                        
                        $lineIndex += 1
                    }
                    
                    # Redraw title to ensure it stays visible (clear the line first)
                    $titleLine = $countdownStartLine + $roleExpirationData.Count + 1  # +1 for space after countdown
                    [Console]::SetCursorPosition(0, $titleLine)
                    Write-Host (" " * [Console]::WindowWidth) # Clear the line
                    [Console]::SetCursorPosition(0, $titleLine)
                    Write-Host $Title -ForegroundColor Cyan
                    
                    $lastUpdate = $currentTime
                }
                
                # Update menu display
                for ($i = 0; $i -lt $Items.Count; $i++) {
                    [Console]::SetCursorPosition(0, $menuStartLine + $i)
                    
                    $item = $Items[$i]
                    $arrow = if ($i -eq $currentIndex) { "► " } else { "  " }
                    $color = if ($i -eq $currentIndex) { "Yellow" } else { "White" }
                    $checkbox = if ($selected[$i]) { "[✓]" } else { "[ ]" }
                    $checkboxColor = if ($selected[$i]) { "Green" } else { "Gray" }
                    
                    # Get display text from RoleName property
                    $displayText = if ($item.RoleName) { $item.RoleName } else { $item.ToString() }
                    
                    Write-Host "$arrow" -NoNewline -ForegroundColor $color
                    Write-Host "$checkbox " -NoNewline -ForegroundColor $checkboxColor
                    Write-Host "$displayText".PadRight([Console]::WindowWidth - $arrow.Length - $checkbox.Length - 1) -ForegroundColor $color
                }
                
                # Update status
                [Console]::SetCursorPosition(0, $statusLine)
                $selectedCount = ($selected.Values | Where-Object { $_ }).Count
                if ($selectedCount -gt 0) {
                    Write-Host ("Roles Selected: $selectedCount").PadRight([Console]::WindowWidth - 1) -ForegroundColor Green
                    } else {
                    Write-Host ("Roles Selected: 0").PadRight([Console]::WindowWidth - 1) -ForegroundColor Gray
                }
                
                # Check for input (non-blocking)
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    switch ($key.Key) {
                        "UpArrow" {
                            $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $Items.Count - 1 }
                        }
                        "DownArrow" {
                            $currentIndex = if ($currentIndex -lt ($Items.Count - 1)) { $currentIndex + 1 } else { 0 }
                        }
                        "Spacebar" {
                            $selected[$currentIndex] = -not $selected[$currentIndex]
                        }
                        "Enter" {
                            $selectedItems = @()
                            for ($i = 0; $i -lt $Items.Count; $i++) {
                                if ($selected[$i]) {
                                    $selectedItems += $i
                                }
                            }
                            # Clear the screen before returning to prevent overlap
                            Clear-Host
                            return $selectedItems
                        }
                        "Escape" {
                            # Clear the screen before returning to prevent overlap
                            Clear-Host
                            return @()
                        }
    
                    }
                    
                    # Handle Ctrl key combinations
                    if ($key.Modifiers -eq "Control") {
                        switch ($key.Key) {
                            "A" {
                                # Ctrl+A - Select all items
                                for ($i = 0; $i -lt $Items.Count; $i++) {
                                    $selected[$i] = $true
                                }
                                # Clear the status area and show selection message
                                [Console]::SetCursorPosition(0, $statusLine)
                                Write-Host "✅ All roles selected".PadRight([Console]::WindowWidth - 1) -ForegroundColor Green
                                Start-Sleep -Milliseconds 800
                            }
                            "D" {
                                # Ctrl+D - Deselect all items
                                for ($i = 0; $i -lt $Items.Count; $i++) {
                                    $selected[$i] = $false
                                }
                                # Clear the status area and show deselection message
                                [Console]::SetCursorPosition(0, $statusLine)
                                Write-Host "❌ All roles deselected".PadRight([Console]::WindowWidth - 1) -ForegroundColor Yellow
                                Start-Sleep -Milliseconds 800
                            }
    
                            "R" {
                                # Ctrl+R - Refresh (will be handled by returning special value)
                                Write-Host ""
                                Write-Host "🔄 Refreshing role status..." -ForegroundColor Cyan
                                Start-Sleep -Milliseconds 500
                                Clear-Host
                                return "REFRESH"
                            }
                            "Q" {
                                # Ctrl+Q - Exit application immediately
                                Clear-Host
                                Write-Host "Exiting PIM role management..." -ForegroundColor Yellow
                                try {
        Disconnect-MgGraph | Out-Null
        Write-Host "Disconnected from Microsoft Graph." -ForegroundColor DarkRed
                    } catch {
                                    Write-Host "Already disconnected from Microsoft Graph." -ForegroundColor DarkGray
                                }
        Write-Host ""
                                Write-Host "Terminal will close in 3 seconds..." -ForegroundColor Cyan
                                Start-Sleep -Seconds 3
                                [Environment]::Exit(0)
                            }
                        }
                    }
                }
                
                # Optimized delay to prevent excessive CPU usage
                Start-Sleep -Milliseconds 250
                
                # Periodic memory optimization and predictive preload (every ~40 seconds)
                if ((Get-Random -Maximum 160) -eq 1) {
                    Optimize-Memory
                    Start-PredictivePreload
                }
                
        } while ($true)
        }
        finally {
            # Keep cursor hidden - calling code manages visibility
        }
    }
    
    function Show-DeactivationCountdown {
        param(
            [array]$TooNewRoles
        )
        
        try {
            [Console]::CursorVisible = $false
        
        Clear-Host
        Show-PIMGlobalHeaderMinimal
        Write-Host ""
        Write-Host "⏰ Time Remaining Until Roles Can Be Deactivated" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   (5-minute minimum activation period required)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   The deactivation menu will automatically refresh when timers expire" -ForegroundColor Cyan
        Write-Host ""
        
        # Remember the starting line for roles
        $roleStartLine = [Console]::CursorTop
        
        # Deduplicate roles by name
        $uniqueRoles = @{}
        $deduplicatedRoles = @()
        foreach ($roleInfo in $TooNewRoles) {
            if (-not $uniqueRoles.ContainsKey($roleInfo.RoleName)) {
                $uniqueRoles[$roleInfo.RoleName] = $true
                $deduplicatedRoles += $roleInfo
            }
        }
        
        # Show initial role lines
        foreach ($roleInfo in $deduplicatedRoles) {
            Write-Host "  ⏳ $($roleInfo.RoleName): --:-- remaining" -ForegroundColor Cyan
        }
        Write-Host ""
        Write-Host "Ctrl+Q to exit" -ForegroundColor Magenta
        
        do {
            $allReady = $true
            
            # Update each role's countdown in place
            for ($i = 0; $i -lt $deduplicatedRoles.Count; $i++) {
                $roleInfo = $deduplicatedRoles[$i]
                try {
                    $activationTime = $roleInfo.ActivationTime
                    $deactivationTime = $activationTime.AddMinutes(5)
                    $timeRemaining = $deactivationTime - (Get-Date)
                    
                    # Position cursor at this role's line
                    $lineNumber = $roleStartLine + $i
                    [Console]::SetCursorPosition(0, $lineNumber)
                    
                    if ($timeRemaining.TotalSeconds -gt 0) {
                        $allReady = $false
                        $minutes = [int][math]::Floor($timeRemaining.TotalMinutes)
                        $seconds = [int][math]::Floor($timeRemaining.TotalSeconds % 60)
                        $timeDisplay = "{0:D2}:{1:D2}" -f $minutes, $seconds
                        
                        # Update only the time part to reduce flicker
                        Write-Host "  ⏳ $($roleInfo.RoleName): $timeDisplay remaining" -ForegroundColor Cyan -NoNewline
                        Write-Host (" " * ([Console]::WindowWidth - [Console]::CursorLeft - 1))
                    } else {
                        Write-Host "  ✅ $($roleInfo.RoleName): Ready for deactivation!" -ForegroundColor Green -NoNewline
                        Write-Host (" " * ([Console]::WindowWidth - [Console]::CursorLeft - 1))
                    }
                } catch {
                    # Position cursor at this role's line
                    $lineNumber = $roleStartLine + $i
                    [Console]::SetCursorPosition(0, $lineNumber)
                    # Clear line and write new content
                    Write-Host (" " * ([Console]::WindowWidth - 1)) -NoNewline
                    [Console]::SetCursorPosition(0, $lineNumber)
                    Write-Host "  ❓ $($roleInfo.RoleName): Unable to check" -ForegroundColor Yellow
                }
            }
            
            # Check if user pressed a key to skip
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if (Test-QuitShortcut -Key $key) {
                    Invoke-PIMExit
                } else {
                Write-Host "Countdown skipped by user." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                        break
                }
                }
            
            if (-not $allReady) {
                Start-Sleep -Seconds 1
            }
            
        } while (-not $allReady)
        
        [Console]::CursorVisible = $false
        
        if ($allReady) {
            Clear-Host
            Show-PIMGlobalHeaderMinimal
            Write-Host ""
            Write-Host "   Refreshing deactivation menu..." -ForegroundColor Cyan
            Start-Sleep -Seconds 2
            return $true
        }
        
        return $false
            
        } finally {
            # Keep cursor hidden - calling code manages visibility
        }
    }
    
    function Show-SinglePageActivationForm {
        param(
            [array]$ValidRoles,
            [array]$RoleItems
        )
        
        $selected = @{}
        $currentStep = 0  # 0 = role selection, 1 = duration, 2 = justification, 3 = ready to submit
        $currentRoleIndex = 0
        $durationInput = ""
        $justificationInput = ""
        
        [Console]::CursorVisible = $false
        
        try {
            do {
                    Clear-Host
                Show-PIMGlobalHeaderMinimal
                Write-Host ""
                Write-Host "Select Roles to Activate" -ForegroundColor Cyan
                Write-Host "========================" -ForegroundColor Cyan
                Write-Host ""
                for ($i = 0; $i -lt $RoleItems.Count; $i++) {
                    $checkbox = if ($selected[$i]) { "[✓]" } else { "[ ]" }
                    $arrow = if ($i -eq $currentRoleIndex -and $currentStep -eq 0) { "► " } else { "  " }
                    $color = if ($i -eq $currentRoleIndex -and $currentStep -eq 0) { "Yellow" } else { "White" }
                    $checkboxColor = if ($selected[$i]) { "Green" } else { "Gray" }
                    
                    Write-Host "$arrow" -NoNewline -ForegroundColor $color
                    Write-Host "$checkbox " -NoNewline -ForegroundColor $checkboxColor
                    Write-Host "$($RoleItems[$i])" -ForegroundColor $color
                }
                
                Write-Host ""
                
                Write-Host ""
                
                # Show fields dynamically based on current step
                if ($currentStep -ge 1) {
                    # Show duration field (step 1)
                    $durationColor = if ($currentStep -eq 1) { "Yellow" } else { "Green" }
                    $durationArrow = if ($currentStep -eq 1) { "► " } else { "✓ " }
                    Write-Host "$durationArrow" -NoNewline -ForegroundColor $durationColor
                    Write-Host "Enter activation duration (e.g., 30M, 1H, 2H30M): " -NoNewline -ForegroundColor $durationColor
                    Write-Host "$durationInput" -ForegroundColor White
                    Write-Host ""
                }
                
                if ($currentStep -ge 2) {
                    # Show reason field (step 2)
                    $reasonColor = if ($currentStep -eq 2) { "Yellow" } else { "Green" }
                    $reasonArrow = if ($currentStep -eq 2) { "► " } else { "✓ " }
                    Write-Host "$reasonArrow" -NoNewline -ForegroundColor $reasonColor
                    Write-Host "Enter reason for activation: " -NoNewline -ForegroundColor $reasonColor
                    Write-Host "$justificationInput" -ForegroundColor White
                    Write-Host ""
                }
                
                # Show selected count
                $selectedCount = ($selected.Keys | Where-Object { $selected[$_] }).Count
                Write-Host ""
                Write-Host "Roles Selected: $selectedCount" -ForegroundColor Cyan
                Write-Host ""
                
                # Show control bar for role selection step
                if ($currentStep -eq 0) {
                    Write-Host "↑/↓ Navigate | SPACE Toggle | Ctrl+A Select All | ENTER Confirm | $(Get-HelpShortcutText) | $(Get-QuitShortcutText)" -ForegroundColor Magenta
                } elseif ($currentStep -eq 1) {
                    Write-Host "Type duration | ENTER Continue | $(Get-QuitShortcutText)" -ForegroundColor Magenta
                } elseif ($currentStep -eq 2) {
                    Write-Host "Type reason | ENTER Activate | $(Get-QuitShortcutText)" -ForegroundColor Magenta
                }
                
                $key = [Console]::ReadKey($true)
                
                    switch ($key.Key) {
                    "UpArrow" {
                        if ($currentStep -eq 0) {
                            $currentRoleIndex = if ($currentRoleIndex -gt 0) { $currentRoleIndex - 1 } else { $RoleItems.Count - 1 }
                        }
                    }
                    "DownArrow" {
                        if ($currentStep -eq 0) {
                            $currentRoleIndex = if ($currentRoleIndex -lt ($RoleItems.Count - 1)) { $currentRoleIndex + 1 } else { 0 }
                        }
                    }
                    "Spacebar" {
                        if ($currentStep -eq 0) {
                            $selected[$currentRoleIndex] = -not $selected[$currentRoleIndex]
                        }
                    }
                    "Enter" {
                        if ($currentStep -eq 0) {
                            # Step 0: Role selection -> Duration
                            $selectedIndices = @()
                            for ($i = 0; $i -lt $RoleItems.Count; $i++) {
                                if ($selected[$i]) {
                                    $selectedIndices += $i
                                }
                            }
                            
                            if ($selectedIndices.Count -eq 0) {
                                Write-Host ""
                                Write-Host "❌ Please select at least one role." -ForegroundColor Red
                                Show-DynamicControlBar -ControlsText "↑↓ Navigate Roles | SPACE Toggle | Select roles first | $(Get-QuitShortcutText)"
                                Start-Sleep -Seconds 2
                                continue
                            }
                            
                            $currentStep = 1  # Move to duration input
                            [Console]::CursorVisible = $true
                            Show-DynamicControlBar -ControlsText "Type duration | ENTER Continue to Reason | $(Get-QuitShortcutText)"
                            
                        } elseif ($currentStep -eq 1) {
                            # Step 1: Duration -> Reason
                            if ([string]::IsNullOrWhiteSpace($durationInput)) {
                                Write-Host ""
                                Write-Host "❌ Please enter a duration." -ForegroundColor Red
                                Show-DynamicControlBar -ControlsText "Type duration | ENTER Continue to Reason | $(Get-QuitShortcutText)"
                                Start-Sleep -Seconds 2
                                continue
                            }
                            
                            $currentStep = 2  # Move to reason input
                            Show-DynamicControlBar -ControlsText "Type reason | ENTER Activate Roles | $(Get-QuitShortcutText)"
                            
                        } elseif ($currentStep -eq 2) {
                            # Step 2: Reason -> Submit
                            if ([string]::IsNullOrWhiteSpace($justificationInput)) {
                                Write-Host ""
                                Write-Host "❌ Please enter a reason." -ForegroundColor Red
                                Show-DynamicControlBar -ControlsText "Type reason | ENTER Activate Roles | $(Get-QuitShortcutText)"
                                Start-Sleep -Seconds 2
                                continue
                            }
                            
                            # Final submission
                            $selectedIndices = @()
                            for ($i = 0; $i -lt $RoleItems.Count; $i++) {
                                if ($selected[$i]) {
                                    $selectedIndices += $i
                                }
                            }
                            
                            return @{
                                SelectedIndices = $selectedIndices
                                Duration = $durationInput
                                Justification = $justificationInput
                            }
                        }
                    }
                    "Backspace" {
                        if ($currentStep -eq 1 -and $durationInput.Length -gt 0) {
                            $durationInput = $durationInput.Substring(0, $durationInput.Length - 1)
                            # Update control bar after backspace
                            Show-DynamicControlBar -ControlsText "Type duration | ENTER Continue to Reason | $(Get-QuitShortcutText)"
                        } elseif ($currentStep -eq 2 -and $justificationInput.Length -gt 0) {
                            $justificationInput = $justificationInput.Substring(0, $justificationInput.Length - 1)
                            # Update control bar after backspace
                            Show-DynamicControlBar -ControlsText "Type reason | ENTER Activate Roles | $(Get-QuitShortcutText)"
                        }
                    }
                    default {
                        # Handle typing in current step's field
                        if ($key.KeyChar -match '[a-zA-Z0-9\s\.,!@#$%^&*()_+=\-\[\]{}|;:''",.<>?/~`]') {
                            if ($currentStep -eq 1) {
                                $durationInput += $key.KeyChar
                                # Update control bar after each character
                                Show-DynamicControlBar -ControlsText "Type duration | ENTER Continue to Reason | $(Get-QuitShortcutText)"
                            } elseif ($currentStep -eq 2) {
                                $justificationInput += $key.KeyChar
                                # Update control bar after each character
                                Show-DynamicControlBar -ControlsText "Type reason | ENTER Activate Roles | $(Get-QuitShortcutText)"
                            }
                        }
                    }
                    "Escape" {
                        return $null
                    }
                }
            } while ($true)
        } finally {
            # Keep cursor hidden - calling code manages visibility
        }
    }
    
    function Show-SimpleMenu {
        param(
            [array]$Items,
            [string]$Title = "Select an option",
            [int]$DefaultSelection = 0
        )
        
        if ($Items.Count -eq 0) {
            Write-Host "No items to select from." -ForegroundColor Red
            return 0
        }
        
        $currentIndex = $DefaultSelection
        [Console]::CursorVisible = $false
        
        try {
            do {
                    Clear-Host
                Show-PIMGlobalHeader
                    Write-Host ""
                Write-Host $Title -ForegroundColor Cyan
                Write-Host $("=" * $Title.Length) -ForegroundColor Cyan
                Write-Host ""
                
                # Display menu items
                for ($i = 0; $i -lt $Items.Count; $i++) {
                    $arrow = if ($i -eq $currentIndex) { "► " } else { "  " }
                    $color = if ($i -eq $currentIndex) { "Yellow" } else { "White" }
                    Write-Host "$arrow$($Items[$i])" -ForegroundColor $color
                }
                
                Write-Host ""
                Write-Host "Use ↑↓ arrow keys to navigate, ENTER to select" -ForegroundColor Gray
                
                $key = [Console]::ReadKey($true)
                
                switch ($key.Key) {
                    "UpArrow" {
                        $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $Items.Count - 1 }
                    }
                    "DownArrow" {
                        $currentIndex = if ($currentIndex -lt ($Items.Count - 1)) { $currentIndex + 1 } else { 0 }
                    }
                    "Enter" {
                        return $currentIndex
                    }
                    "Escape" {
                        return -1
                    }
                }
            } while ($true)
        } finally {
            # Keep cursor hidden - calling code manages visibility
        }
    }
    
    function Show-CheckboxMenu {
        param(
            [array]$Items,
            [string]$Title = "Select Items",
            [string]$Prompt = "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:",
            [switch]$AllowMultiple = $true,
            [switch]$SingleSelection = $false,
            [switch]$PreserveContent = $false,
            [switch]$KeepSelectionVisible = $false,
            [string]$DisplayProperty = $null
        )
        
        if ($Items.Count -eq 0) {
            Write-Host "No items to select from." -ForegroundColor Red
            return @()
        }
        
        # Initialize selection state
        $selected = @{}
        $currentIndex = 0
        
        # For single selection mode, initialize with nothing selected
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $selected[$i] = $false
        }
        
        # Hide cursor for cleaner display
        [Console]::CursorVisible = $false
        
        try {
            [Console]::CursorVisible = $false
            
            # Simple clean approach - just redraw everything each time
            do {
                    Clear-Host
                Show-PIMGlobalHeaderMinimal
                    Write-Host ""
                Write-Host $Title -ForegroundColor Cyan
                Write-Host $("=" * $Title.Length) -ForegroundColor Cyan
                Write-Host ""
                
                # Show all roles
                for ($i = 0; $i -lt $Items.Count; $i++) {
                    $item = $Items[$i]
                    $checkbox = if ($selected[$i]) { "[✓]" } else { "[ ]" }
                    $arrow = if ($i -eq $currentIndex) { "► " } else { "  " }
                    
                    # Get display text
                    $displayText = if ($DisplayProperty -and $item.PSObject.Properties[$DisplayProperty]) {
                        $item.$DisplayProperty
                        } else {
                        $item.ToString()
                    }
                    
                    $line = "$arrow$checkbox $displayText"
                    
                    # Apply colors
                    if ($selected[$i]) {
                        Write-Host $line -ForegroundColor Green
                } else {
                        Write-Host $line -ForegroundColor White
                    }
                }
                
                Write-Host ""
                $selectedCount = ($selected.GetEnumerator() | Where-Object { $_.Value }).Count
                # Check if this is the main workflow menu based on title
                $menuText = if ($Title -eq "🔄 Choose Action") { "Workflow Selected: $selectedCount" } else { "Roles Selected: $selectedCount" }
                Write-Host $menuText -ForegroundColor Cyan
                Write-Host ""
                # Show control bar for navigation (different for single vs multi-selection)
                $controlBarTop = [Console]::CursorTop
                if ($SingleSelection) {
                    Write-Host "↑/↓ Navigate | SPACE Select | ENTER Confirm | $(Get-HelpShortcutText) | $(Get-QuitShortcutText)" -ForegroundColor Magenta
                } else {
                    Write-Host "↑/↓ Navigate | SPACE Toggle | Ctrl+A Select All | ENTER Confirm | $(Get-HelpShortcutText) | $(Get-QuitShortcutText)" -ForegroundColor Magenta
                }
                
                # Get user input
                $key = [Console]::ReadKey($true)
                
                switch ($key.Key.ToString()) {
                    "UpArrow" {
                        $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $Items.Count - 1 }
                    }
                    "DownArrow" {
                        $currentIndex = if ($currentIndex -lt ($Items.Count - 1)) { $currentIndex + 1 } else { 0 }
                    }
                    "Spacebar" {
                        if ($SingleSelection) {
                            # Clear all selections first for single selection mode
                            for ($i = 0; $i -lt $Items.Count; $i++) {
                                $selected[$i] = $false
                            }
                            # Select only the current item
                            $selected[$currentIndex] = $true
                        } else {
                            $selected[$currentIndex] = -not $selected[$currentIndex]
                        }
                    }
                    "Enter" {
                        $selectedItems = @()
                        for ($i = 0; $i -lt $Items.Count; $i++) {
                            if ($selected[$i]) {
                                $selectedItems += $i
                            }
                        }
                        # Clear the control bar line and several lines below to remove stale content
                        for ($clearLine = $controlBarTop; $clearLine -lt [Math]::Min($controlBarTop + 10, [Console]::BufferHeight); $clearLine++) {
                            [Console]::SetCursorPosition(0, $clearLine)
                            Write-Host (" " * [Console]::WindowWidth) -NoNewline
                        }
                        [Console]::SetCursorPosition(0, $controlBarTop)
                        return $selectedItems
                    }
                    "Escape" {
                        return @()
                    }
                    "Q" {
                        # Only exit if Ctrl is held
                        if ($key.Modifiers -eq "Control") {
                            Invoke-PIMExit -Message "Exiting PIM role management..."
                        }
                    }
                }

                # Handle Ctrl key combinations
                if ($key.Modifiers -eq "Control") {
                    switch ($key.Key) {
                        "H" {
                            # Ctrl+H - Show help menu
                            Show-HelpMenu
                        }
                        "A" {
                            # Ctrl+A - Toggle select/deselect all items (only if not single selection)
                            if (-not $SingleSelection) {
                                $allSelected = ($selected | Where-Object { $_ -eq $true }).Count -eq $selected.Count
                                for ($i = 0; $i -lt $Items.Count; $i++) {
                                    $selected[$i] = -not $allSelected
                                }
                            }
                        }
                        "D" {
                            # Ctrl+D - Deselect all items
                            for ($i = 0; $i -lt $Items.Count; $i++) {
                                $selected[$i] = $false
                            }
                        }
                        "R" {
                            # Ctrl+R - Refresh (return special value)
                            return "REFRESH"
                        }
                        "Q" {
                            # Use centralized exit handler
                            if ($key.Modifiers -eq 'Control') {
                                Invoke-PIMExit -Message "Exiting PIM role management..."
                            }
                        }
                    }
                }
            } while ($true)
        }
        finally {
            # Keep cursor hidden - calling code manages visibility
        }
    }
    
    # Optimized pending role detection with ultra-fast discovery
    function Get-PendingApprovalRequestsLocal {
        param([string]$CurrentUserId)
        
        try {
            # ULTRA FAST: Just get recent requests with a limit to avoid long waits
            $recentRequests = Get-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -Filter "PrincipalId eq '$CurrentUserId'" -Top 10
            
            # Only consider requests from the last 24 hours to avoid stale data
            $cutoffTime = (Get-Date).AddHours(-24)
            
            # Filter for recent pending, approved, AND provisioned requests that haven't been activated yet
            $pendingRequests = $recentRequests | Where-Object {
                ($_.Status -eq "PendingApproval" -or $_.Status -eq "Approved" -or $_.Status -eq "Provisioned") -and
                $_.Action -eq "selfActivate" -and
                $_.CreatedDateTime -gt $cutoffTime
            }
            
            return $pendingRequests
        } catch {
            # Skip pending check entirely if it fails - don't let it block the app
            return @()
        }
    }
    
    # ========================= WORKFLOW FUNCTIONS =========================
    
    
    function Start-PIMRoleManagement {
        param(
            [string]$CurrentUserId
        )
        
        [Console]::CursorVisible = $false
        Clear-Host
        Show-PIMGlobalHeaderMinimal
        
        # Create main choice menu items
        $menuItems = @(
            "Activate Roles",
            "Deactivate Roles"
        )
        
        # Show checkbox menu with single selection
        $selectedIndices = Show-CheckboxMenu -Items $menuItems -Title "🔄 Choose Action" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -SingleSelection
        
        if ($selectedIndices.Count -eq 0) {
            return
        }
        
        $selectedIndex = $selectedIndices[0]
        $selectedAction = $menuItems[$selectedIndex]
        
        [Console]::CursorVisible = $false
        
        if ($selectedAction -eq "Activate Roles") {
            # Show loading message, then load roles
            Clear-Host
            Show-PIMGlobalHeaderMinimal
            Write-Host ""
            Write-Host "🔄 Loading eligible roles..." -ForegroundColor Cyan -NoNewline
            $eligibleRoles = Get-EligibleRolesOptimized -CurrentUserId $CurrentUserId
            if ($eligibleRoles.Count -gt 0) {
                Write-Host " ✅ $($eligibleRoles.Count) found" -ForegroundColor Green
            } else {
                Write-Host "" # Complete the loading line
                Write-Host "" # Add spacing before error message
            }
            Start-RoleActivationWorkflow -ValidRoles $eligibleRoles -CurrentUserId $CurrentUserId
        } elseif ($selectedAction -eq "Deactivate Roles") {
            # Show loading message, then load roles
            Clear-Host
            Show-PIMGlobalHeaderMinimal
            Write-Host ""
            Write-Host "🔄 Loading active roles..." -ForegroundColor Cyan -NoNewline
            $activeRoles = Get-ActiveRolesOptimized -CurrentUserId $CurrentUserId
            if ($activeRoles.Count -gt 0) {
                Write-Host " ✅ $($activeRoles.Count) found" -ForegroundColor Green
            } else {
                Write-Host "" # New line before error message
            }
            Start-RoleDeactivationWorkflow -ActiveRoles $activeRoles -CurrentUserId $CurrentUserId
        }
    }
    
    function Start-RoleActivationWorkflowWithCheck {
        param(
            [string]$CurrentUserId,
            [switch]$SkipDeactivationOffer
        )
        
        # Show loading message
        Clear-Host
        Show-PIMGlobalHeaderMinimal
        Write-Host ""
        Write-Host "🔄 Loading eligible roles..." -ForegroundColor Cyan -NoNewline
        $validRoles = Get-EligibleRolesOptimized -CurrentUserId $CurrentUserId
        
        if ($validRoles.Count -eq 0) {
            Write-Host ""
            Write-Host ""
            # Clear screen and start fresh to remove old controls
            Clear-Host
            Show-PIMGlobalHeaderMinimal
            Write-Host ""
            Write-Host "ℹ️  No roles available for activation at this time." -ForegroundColor Gray
            Write-Host ""
            
            if ($SkipDeactivationOffer) {
                # Don't offer deactivation since we came from deactivation workflow
                Write-Host "❌ No role management workflows available." -ForegroundColor Red
                    Write-Host ""
                    Write-Host "Check back later when roles are approved or activated." -ForegroundColor Gray
                    Show-DynamicControlBar
                    
                    # Hide cursor and wait for Ctrl+Q to exit
                    [Console]::CursorVisible = $false
                    do {
                        $key = [Console]::ReadKey($true)
                        if (Test-QuitShortcut -Key $key) {
                            Invoke-PIMExit -Message "Exiting PIM role management..."
                        }
                    } while ($true)
                    return
                Write-Host ""
                Write-Host "Returning to main menu..." -ForegroundColor Gray
                Start-Sleep -Seconds 1
                return
            } else {
                # Get user input with proper cursor positioning
                do {
                    $userInput = Read-PIMInput -Prompt "Would you like to check for roles to deactivate instead? (Y/N)" -ControlsText $script:ControlMessages['Exit']
                    $userInput = $userInput.Trim().ToUpper()
                    if ($userInput -eq "Y" -or $userInput -eq "YES") {
                        $continueChoice = "Yes"
                        break
                    } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
                        $continueChoice = "No"
                        break
                } else {
                        Write-PIMHost "Please enter Y or N." -ForegroundColor Yellow -ControlsText $script:ControlMessages['Exit']
                    }
                } while ($true)
                
                # Show controls at the bottom after user responds
                Write-Host ""
                
                if ($continueChoice -eq "Yes") {
                    # Go directly to deactivation workflow
                    Start-RoleDeactivationWorkflowWithCheck -CurrentUserId $CurrentUserId
                } else {
                    Show-NoWorkflowsAndWaitForExit
                    return
                }
            }
            return
        }
        
        # Continue to activation workflow
        Start-RoleActivationWorkflow -ValidRoles $validRoles -CurrentUserId $CurrentUserId
    }

# Move Start-RoleDeactivationWorkflow to global scope  
function Start-RoleDeactivationWorkflow {
    param(
        [array]$ActiveRoles,
        [string]$CurrentUserId
    )
    
    
    # Get cached schedules for activation time checking
    try {
        $cachedSchedules = Get-CachedSchedules -CurrentUserId $CurrentUserId
    } catch {
        $cachedSchedules = @()
    }
        [Console]::CursorVisible = $false
        if ($ActiveRoles.Count -eq 0) {
            Write-Host "❌ No active roles available for deactivation." -ForegroundColor Red
            return
        }  
    # Check for roles that are too new to deactivate (5-minute rule)
    # Use StartDateTime from assignment directly - more reliable than cached schedules
    $readyToDeactivate = @()
    $tooNewRoles = @()
    
    foreach ($role in $ActiveRoles) {
        try {
            $assignment = $role.Assignment
            $activationTime = $null
            
            # Use individual activation time from API (same approach as Start-RoleDeactivationWorkflowWithCheck)
            if ($assignment.StartDateTime) {
                $activationTime = [DateTime]::Parse($assignment.StartDateTime).ToLocalTime()
            }
            
            if ($activationTime) {
                $timeSinceActivation = (Get-Date) - $activationTime
                
                if ($timeSinceActivation.TotalMinutes -lt 5) {
                    $tooNewRoles += [PSCustomObject]@{
                        RoleName = $role.RoleName
                        ActivationTime = $activationTime
                        Assignment = $role.Assignment
                    }
                } else {
                    $readyToDeactivate += $role
                }
            } else {
                # No activation time available, assume it's ready (old activation)
                $readyToDeactivate += $role
            }
        } catch {
            # If there's an error checking, assume it's ready
            $readyToDeactivate += $role
        }
    }
    
    # If some roles are too new, show countdown
    if ($tooNewRoles.Count -gt 0) {
        [Console]::CursorVisible = $false
        Clear-Host
        Show-PIMGlobalHeaderMinimal
        Write-Host ""
        
        if ($readyToDeactivate.Count -eq 0) {
            Write-Host "⏰ All roles are within the 5-minute activation period." -ForegroundColor Yellow
            Write-Host "Showing countdown until they can be deactivated..." -ForegroundColor Cyan
        } else {
            Write-Host "⏰ Some roles are within the 5-minute activation period." -ForegroundColor Yellow
            Write-Host "Showing countdown for roles that cannot be deactivated yet..." -ForegroundColor Cyan
        }
        Write-Host ""
        
        $countdownResult = Show-DeactivationCountdown -TooNewRoles $tooNewRoles
        
        # If countdown completed successfully, continue to deactivation workflow
        if ($countdownResult -eq $true) {
            Start-RoleDeactivationWorkflow -ActiveRoles $ActiveRoles -CurrentUserId $CurrentUserId
        }
        return
    }
    
    # If no roles are ready for deactivation, inform user and return
    if ($readyToDeactivate.Count -eq 0) {
        Write-Host "ℹ️  All roles are currently within the 5-minute activation period." -ForegroundColor Gray
        Write-Host ""
        
        # Ask if user wants to activate roles instead with inline input handling
        Write-Host "Would you like to activate roles instead? (Y/N): " -NoNewline -ForegroundColor Cyan
        
        # Show cursor for Y/N input
        [Console]::CursorVisible = $true
        
        # Store cursor position for inline input
        $promptLeft = [Console]::CursorLeft
        $promptTop = [Console]::CursorTop
        
        # Show control bar below the prompt with proper spacing
        Write-Host "`n"  # Add blank line after prompt
        Write-Host "Ctrl+Q to exit" -ForegroundColor Magenta
        $script:LastControlBarLine = [Console]::CursorTop - 1
        
        # Return cursor to inline position after the prompt (same line as Y/N question)
        [Console]::SetCursorPosition($promptLeft, $promptTop)
        
        $userInput = ""
        do {
            $key = [Console]::ReadKey($true)
            
            # Check for Ctrl+Q
            if (Test-QuitShortcut -Key $key) {
                Invoke-PIMExit
                return
            }
            
            # Handle Enter key
            if ($key.Key -eq 'Enter') {
                if ($userInput -eq 'Y' -or $userInput -eq 'y') {
                    # Clear the control bar and move cursor to start of that line
                    if ($script:LastControlBarLine -ge 0) {
                        try {
                            [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                            Write-Host (" " * [Console]::WindowWidth) -NoNewline
                            $script:LastControlBarLine = -1
                        } catch { }
                    }
                    Clear-Host
                                        Start-PIMRoleManagement -CurrentUserId $CurrentUserId
                                        return
                } elseif ($userInput -eq 'N' -or $userInput -eq 'n') {
                    Write-Host ""
                    Show-NoWorkflowsAndWaitForExit
                    return
                } else {
                    Write-Host ""
                    Write-Host "Please enter Y or N: " -NoNewline -ForegroundColor Yellow
                    # Clear and redraw control bar for invalid input
                    if ($script:LastControlBarLine -ge 0) {
                        try {
                            [Console]::SetCursorPosition(0, $script:LastControlBarLine)
                            Write-Host (" " * [Console]::WindowWidth) -NoNewline
                        } catch { }
                    }
                    Write-Host ""
                    Write-Host "Ctrl+Q to exit" -ForegroundColor Magenta
                    $script:LastControlBarLine = [Console]::CursorTop - 1
                    # Return cursor to prompt position
                    [Console]::SetCursorPosition([Console]::CursorLeft, [Console]::CursorTop - 2)
                    $userInput = ""
                }
            }
            # Handle backspace
            elseif ($key.Key -eq 'Backspace' -and $userInput.Length -gt 0) {
                $userInput = $userInput.Substring(0, $userInput.Length - 1)
                Write-Host "`b `b" -NoNewline
            }
            # Handle regular characters (Y/N only)
            elseif ($key.KeyChar -match '[YyNn]' -and $userInput.Length -eq 0) {
                $userInput = $key.KeyChar.ToString().ToUpper()
                Write-Host $userInput -NoNewline -ForegroundColor Green
            }
        } while ($true)
        
        if ($continueChoice -eq "Yes") {
            # Return to choice menu
            return
        } else {
            Write-Host "❌ No role management workflows available." -ForegroundColor Red
                    Write-Host ""
                    Write-Host "Check back later when roles are approved or activated." -ForegroundColor Gray
                    Show-DynamicControlBar
                    
                    # Hide cursor and wait for Ctrl+Q to exit
                    [Console]::CursorVisible = $false
                    do {
                        $key = [Console]::ReadKey($true)
                        if (Test-QuitShortcut -Key $key) {
                            Invoke-PIMExit -Message "Exiting PIM role management..."
                        }
                    } while ($true)
                    return
            Write-Host "Script completed successfully." -ForegroundColor Green
        }
        return
    }
    
    # Get role expiration data for countdown display
    try {
        $roleExpirationData = @()
        
        foreach ($role in $readyToDeactivate) {
            $assignment = $role.Assignment
            $schedules = $cachedSchedules | Where-Object { 
                $_.PrincipalId -eq $assignment.PrincipalId -and 
                $_.RoleDefinitionId -eq $assignment.RoleDefinitionId 
            }
            $schedule = $schedules | Sort-Object CreatedDateTime -Descending | Select-Object -First 1
            
            if ($schedule.ScheduleInfo.Expiration.EndDateTime) {
                $expirationTime = [DateTime]::Parse($schedule.ScheduleInfo.Expiration.EndDateTime).ToLocalTime()
                $roleExpirationData += [PSCustomObject]@{
                    RoleName = $role.RoleName
                    ExpirationTime = $expirationTime
                    Assignment = $assignment
                    Index = $readyToDeactivate.IndexOf($role)
                }
            }
        }
        
        # Remove duplicates
        $roleExpirationData = $roleExpirationData | Sort-Object RoleName, ExpirationTime -Descending | Group-Object RoleName | ForEach-Object { $_.Group[0] }
        
    } catch {
        Write-Host "⚠️ Could not retrieve role expiration data for countdown display: $($_.Exception.Message)" -ForegroundColor Yellow
        $roleExpirationData = @()
    }
    
    # Use countdown menu if we have expiration data
    # Clear screen before showing menu to remove any stale content
    Clear-Host
    if ($roleExpirationData.Count -gt 0) {
        $selectedIndices = Show-CheckboxMenu -Items $readyToDeactivate -Title "🔄 Select Active Roles to Deactivate" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -DisplayProperty "RoleName"
    } else {
        # OPTIMIZED: Batch get all expiration data in single API call
        $allScheduleInstances = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -Filter "PrincipalId eq '$CurrentUserId' and AssignmentType eq 'Activated'" -All
        $scheduleInstanceLookup = @{}
        foreach ($instance in $allScheduleInstances) {
            $scheduleInstanceLookup[$instance.RoleDefinitionId] = $instance
        }
        
        $roleItemsWithExpiration = @()
        foreach ($role in $readyToDeactivate) {
            $assignment = $role.Assignment
            
            # Get expiration time from lookup table (O(1) access)
            try {
                $scheduleInstance = $scheduleInstanceLookup[$assignment.RoleDefinitionId]
                
                if ($scheduleInstance -and $scheduleInstance.EndDateTime) {
                    $expirationTime = [DateTime]::Parse($scheduleInstance.EndDateTime).ToLocalTime()
                    $timeRemaining = $expirationTime - (Get-Date)
                    
                    
                    if ($timeRemaining.TotalSeconds -gt 0) {
                        $hours = [Math]::Floor($timeRemaining.TotalHours)
                        $minutes = $timeRemaining.Minutes
                        $seconds = $timeRemaining.Seconds
                        
                        if ($hours -gt 0) {
                            $countdownText = "expires in ${hours}h ${minutes}m"
                        } else {
                            $countdownText = "expires in ${minutes}m ${seconds}s"
                        }
                        
                        $roleItemsWithExpiration += "$($role.RoleName) ($countdownText)"
                    } else {
                        $roleItemsWithExpiration += "$($role.RoleName) (expired)"
                    }
                } else {
                    # Try alternative approach using cached schedules
                    $cachedSchedules = Get-CachedSchedules -CurrentUserId $CurrentUserId
                    $schedules = $cachedSchedules | Where-Object { 
                        $_.PrincipalId -eq $assignment.PrincipalId -and 
                        $_.RoleDefinitionId -eq $assignment.RoleDefinitionId 
                    }
                    $schedule = $schedules | Sort-Object CreatedDateTime -Descending | Select-Object -First 1
                    
                    if ($schedule.ScheduleInfo.Expiration.EndDateTime) {
                        $expirationTime = [DateTime]::Parse($schedule.ScheduleInfo.Expiration.EndDateTime).ToLocalTime()
                        $timeRemaining = $expirationTime - (Get-Date)
                        
                        if ($timeRemaining.TotalSeconds -gt 0) {
                            $hours = [Math]::Floor($timeRemaining.TotalHours)
                            $minutes = $timeRemaining.Minutes
                            
                            if ($hours -gt 0) {
                                $countdownText = "expires in ${hours}h ${minutes}m"
                            } else {
                                $countdownText = "expires in ${minutes}m"
                            }
                            
                            $roleItemsWithExpiration += "$($role.RoleName) ($countdownText)"
                        } else {
                            $roleItemsWithExpiration += "$($role.RoleName) (expired)"
                        }
                    } else {
                        $roleItemsWithExpiration += "$($role.RoleName) (no expiration data)"
                    }
                }
            } catch {
                $roleItemsWithExpiration += "$($role.RoleName) (expiration unknown)"
            }
        }
        $selectedIndices = Show-CheckboxMenu -Items $roleItemsWithExpiration -Title "🔄 Select Active Roles to Deactivate" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:"
    }
    
    if ($selectedIndices.Count -eq 0) {
                Write-Host "❌ No roles selected for deactivation." -ForegroundColor Yellow
        return
    }
    
    # Clear screen and show clean deactivation progress
    Clear-Host
    Show-PIMGlobalHeaderMinimal
    Write-Host ""
    Write-Host "🔄 Deactivating $($selectedIndices.Count) role(s)..." -ForegroundColor Cyan
    Write-Host ""
    
    $successCount = 0
    $failCount = 0
    $skippedCount = 0
    
    foreach ($index in $selectedIndices) {
        # Validate index
        if ($index -lt 0 -or $index -ge $readyToDeactivate.Count) {
            Write-Host "⚠️ Invalid selection index: $index" -ForegroundColor Yellow
            continue
        }
        
        $role = $readyToDeactivate[$index]
        $assignment = $role.Assignment
        $roleName = $role.RoleName
        
        try {
            # Validate assignment data
            if (-not $assignment.PrincipalId -or -not $assignment.RoleDefinitionId) {
                Write-Host "   ❌ Invalid assignment data for: $roleName" -ForegroundColor Red
                $failCount++
                continue
            }
            
            # Create deactivation request
            $deactivationRequest = @{
                action = "selfDeactivate"
                principalId = $assignment.PrincipalId
                roleDefinitionId = $assignment.RoleDefinitionId
                directoryScopeId = if ($assignment.DirectoryScopeId) { $assignment.DirectoryScopeId } else { "/" }
            }
            
            # Make the deactivation request with retry logic for network errors
            $maxRetries = 3
            $retryCount = 0
            $deactivationSuccess = $false
            
            while (-not $deactivationSuccess -and $retryCount -lt $maxRetries) {
                try {
                    $result = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $deactivationRequest -ErrorAction Stop
                    $deactivationSuccess = $true
                    
                    if ($result) {
                        Write-Host "✅ Successfully deactivated: $roleName" -ForegroundColor Green
                        $successCount++
                        
                        # Clear cache to ensure fresh data
                        $script:ScheduleInstanceCache = @{}
                        $script:ScheduleInstanceCacheExpiry = (Get-Date).AddSeconds(-1)
                        $global:ActiveRoleCache = @()
                        $global:ActiveRoleCacheTime = $null
                    }
                } catch {
                    $errorMessage = $_.Exception.Message
                    if ($errorMessage -like "*RoleAssignmentDoesNotExist*") {
                        # If we retried due to network error and now it's gone, the first request likely succeeded
                        if ($retryCount -gt 0) {
                            Write-Host "✅ Successfully deactivated: $roleName (confirmed on retry)" -ForegroundColor Green
                            $successCount++
                        } else {
                            Write-Host "⚠️ Role already deactivated: $roleName" -ForegroundColor Yellow
                            $skippedCount++
                        }
                        $deactivationSuccess = $true
                    } elseif ($errorMessage -like "*error occurred while sending the request*") {
                        $retryCount++
                        if ($retryCount -lt $maxRetries) {
                            Write-Host "⚠️ Network error, retrying $roleName ($retryCount/$maxRetries)..." -ForegroundColor Yellow
                            Start-Sleep -Seconds 2
                        } else {
                            Write-Host "❌ Failed to deactivate: $roleName after $maxRetries retries" -ForegroundColor Red
                            $failCount++
                        }
                    } else {
                        Write-Host "❌ Failed to deactivate: $roleName" -ForegroundColor Red
                        $failCount++
                        $deactivationSuccess = $true
                    }
                }
            }
        } catch {
            Write-Host "❌ Failed to deactivate: $roleName" -ForegroundColor Red
            $failCount++
        }
    }
    
    Write-Host ""
    
    # Ask if user wants to manage more roles
    do {
        [Console]::CursorVisible = $true
        $userInput = Read-PIMInput -Prompt "Would you like to manage more roles? (Y/N)" -ControlsText $script:ControlMessages['Exit']
        if (-not $userInput) { continue }
        $userInput = $userInput.Trim().ToUpper()
        if ($userInput -eq "Y" -or $userInput -eq "YES") {
            $continueChoice = "Yes"
            break
        } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
            $continueChoice = "No"
            break
        } else {
            Write-Host "Please enter Y or N." -ForegroundColor Yellow
        }
    } while ($true)
        
        if ($continueChoice -eq "Yes") {
            # Return to main workflow selector (Entra/Azure choice)
            return
        } else {
            Write-Host "No additional roles will be managed." -ForegroundColor Red
            Write-Host ""
            Write-Host "Please close the terminal." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

            # Hide cursor and wait for user to exit with Ctrl+Q
            [Console]::CursorVisible = $false
            do {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if (Test-GlobalShortcut -Key $key) {
                        return
                    }
                }
                Start-Sleep -Milliseconds 100
            } while ($true)
        }
    }

# ========================= MAIN SCRIPT EXECUTION =========================

# ========================= Workflow Selection =========================

function Show-WorkflowSelector {
    $menuItems = @(
        "Entra ID Roles",
        "Azure Resource Roles"
    )

    $selectedIndices = Show-CheckboxMenu -Items $menuItems -Title "🔄 Select Workflow" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -SingleSelection

    if ($null -eq $selectedIndices -or $selectedIndices.Count -eq 0) {
        return 'Quit'
    }

    $selectedIndex = $selectedIndices[0]
    switch ($selectedIndex) {
        0 { return 'Entra' }
        1 { return 'Azure' }
        default { return 'Quit' }
    }
}

# ========================= Azure PIM Functions =========================

$script:AzureSelectedSubscriptions = @()

function Invoke-AzurePIMApi {
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

function Get-AzureEligibleRoles {
    param([switch]$Force)

    if (-not $script:AzureSelectedSubscriptions -or $script:AzureSelectedSubscriptions.Count -eq 0) {
        return @()
    }

    $allEligibleRoles = @()

    foreach ($sub in $script:AzureSelectedSubscriptions) {
        Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue | Out-Null
        $path = "/subscriptions/$($sub.Id)/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?api-version=2020-10-01&`$filter=asTarget()"

        try {
            $response = Invoke-AzurePIMApi -Path $path -Method "GET"

            if ($response.value) {
                foreach ($role in $response.value) {
                    $allEligibleRoles += [PSCustomObject]@{
                        Id               = $role.id
                        Name             = $role.name
                        RoleDefinitionId = $role.properties.roleDefinitionId
                        RoleDisplayName  = $role.properties.expandedProperties.roleDefinition.displayName
                        Scope            = $role.properties.scope
                        ScopeDisplayName = $role.properties.expandedProperties.scope.displayName
                        ScopeType        = $role.properties.expandedProperties.scope.type
                        PrincipalId      = $role.properties.principalId
                        SubscriptionId   = $sub.Id
                        SubscriptionName = $sub.Name
                    }
                }
            }
        } catch {
            Write-Host "  ⚠️ Could not query subscription '$($sub.Name)'" -ForegroundColor Yellow
        }
    }

    return $allEligibleRoles
}

function Get-AzureActiveRoles {
    param([switch]$Force)

    if (-not $script:AzureSelectedSubscriptions -or $script:AzureSelectedSubscriptions.Count -eq 0) {
        return @()
    }

    $allActiveRoles = @()

    foreach ($sub in $script:AzureSelectedSubscriptions) {
        Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue | Out-Null
        $path = "/subscriptions/$($sub.Id)/providers/Microsoft.Authorization/roleAssignmentScheduleInstances?api-version=2020-10-01&`$filter=asTarget()"

        try {
            $response = Invoke-AzurePIMApi -Path $path -Method "GET"

            if ($response.value) {
                foreach ($role in $response.value) {
                    if ($role.properties.assignmentType -eq "Activated") {
                        $allActiveRoles += [PSCustomObject]@{
                            Id               = $role.id
                            Name             = $role.name
                            RoleDefinitionId = $role.properties.roleDefinitionId
                            RoleDisplayName  = $role.properties.expandedProperties.roleDefinition.displayName
                            Scope            = $role.properties.scope
                            ScopeDisplayName = $role.properties.expandedProperties.scope.displayName
                            PrincipalId      = $role.properties.principalId
                            StartDateTime    = $role.properties.startDateTime
                            EndDateTime      = $role.properties.endDateTime
                            SubscriptionId   = $sub.Id
                            SubscriptionName = $sub.Name
                        }
                    }
                }
            }
        } catch {
            Write-Host "  ⚠️ Could not query subscription '$($sub.Name)'" -ForegroundColor Yellow
        }
    }

    return $allActiveRoles
}

function Start-AzureRoleActivation {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$EligibleRole,
        [Parameter(Mandatory)]
        [string]$Justification,
        [Parameter(Mandatory)]
        [string]$Duration
    )

    try {
        Set-AzContext -SubscriptionId $EligibleRole.SubscriptionId -ErrorAction SilentlyContinue | Out-Null

        $scope = $EligibleRole.Scope
        $requestName = [guid]::NewGuid().ToString()
        $path = "${scope}/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/${requestName}?api-version=2020-10-01"

        $body = @{
            properties = @{
                principalId      = $EligibleRole.PrincipalId
                roleDefinitionId = $EligibleRole.RoleDefinitionId
                requestType      = "SelfActivate"
                justification    = $Justification
                scope            = $scope
                scheduleInfo     = @{
                    startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    expiration    = @{
                        type     = "AfterDuration"
                        duration = $Duration
                    }
                }
            }
        }

        $response = Invoke-AzurePIMApi -Path $path -Method "PUT" -Body $body
        return ($null -ne $response)
    } catch {
        Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Stop-AzureRoleActivation {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ActiveRole
    )

    try {
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
        return ($null -ne $response)
    } catch {
        Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Start-AzurePIMWorkflow {
    $script:CurrentWorkflow = 'Azure'

    # Pre-load MSAL for browser-based auth with ForceLogin
    $msalInitialized = Initialize-MSALAssemblies
    if ($msalInitialized) {
        try {
            $null = Initialize-MSALHelper
        } catch {
            # MSAL helper init failed - will fall back to standard auth
        }
    }

    # Load Az modules with progress bar
    Clear-Host
    Write-Host ""
    Write-Host "[ A Z U R E   P I M ]" -ForegroundColor Cyan
    Write-Host "    with PowerShell" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "Loading Azure modules..." -ForegroundColor Cyan
    Write-Host ""

    $requiredAzModules = @("Az.Accounts")
    $barWidth = 30
    $currentModule = 0
    $totalModules = $requiredAzModules.Count

    foreach ($module in $requiredAzModules) {
        $currentModule++
        $percent = [math]::Floor(($currentModule / $totalModules) * 100)
        $filled = [math]::Floor(($currentModule / $totalModules) * $barWidth)
        $empty = $barWidth - $filled
        $bar = "█" * $filled + "░" * $empty

        Write-Host "  [$bar] $percent% " -NoNewline -ForegroundColor Yellow
        Write-Host "Loading: " -NoNewline -ForegroundColor Gray
        Write-Host "$module" -ForegroundColor White

        if (-not (Get-Module -ListAvailable -Name $module)) {
            Install-Module $module -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        }
        Import-Module $module -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "  ✓ All modules ready!" -ForegroundColor Green
    Write-Host ""

    # Authenticate - Use MSAL with ForceLogin to support step-up authentication
    Write-Host "Opening browser for authentication..." -ForegroundColor Cyan
    Write-Host "Waiting for authentication response..." -ForegroundColor Yellow

    try {
        # Clear existing context
        Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
        Clear-AzContext -Force -ErrorAction SilentlyContinue | Out-Null

        # Use MSAL with ForceLogin prompt for Azure management scope
        $azureManagementScope = @("https://management.azure.com/.default")
        $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"  # Azure PowerShell client ID

        # Get token using MSAL with ForceLogin (requires passkey/step-up auth)
        $accessToken = [PIMBrowserAuth]::GetAccessToken($clientId, $azureManagementScope)

        if (-not $accessToken) {
            throw "Failed to acquire access token"
        }

        # Decode JWT to get account ID and tenant ID
        $tokenParts = $accessToken.Split('.')
        $payload = $tokenParts[1]
        # Add padding if needed
        $padding = 4 - ($payload.Length % 4)
        if ($padding -ne 4) { $payload += '=' * $padding }
        $decodedPayload = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
        $claims = $decodedPayload | ConvertFrom-Json
        $accountId = if ($claims.upn) { $claims.upn } elseif ($claims.preferred_username) { $claims.preferred_username } else { $claims.sub }
        $tenantId = $claims.tid

        # Connect to Azure using the MSAL token (without SkipValidation to avoid needing subscription)
        $null = Connect-AzAccount -AccessToken $accessToken -AccountId $accountId -Tenant $tenantId -ErrorAction Stop

        $context = Get-AzContext
        if (-not $context) {
            throw "Failed to establish Azure context"
        }

        Write-Host "✅ Successfully connected to Azure" -ForegroundColor Green
        Write-Host "✅ Account: $($context.Account.Id)" -ForegroundColor Green

        # Get subscriptions
        $subscriptions = @(Get-AzSubscription -ErrorAction SilentlyContinue)
        if ($subscriptions.Count -eq 0) {
            Write-Host "❌ No subscriptions found" -ForegroundColor Red
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
            return
        }

        # Use existing UI for subscription selection
        $subItems = $subscriptions | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                Id = $_.Id
            }
        }

        $selectedSubIndices = Show-CheckboxMenu -Items $subItems -Title "📦 Select Subscription" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -DisplayProperty "Name" -SingleSelection

        if ($selectedSubIndices.Count -eq 0) {
            return
        }

        $selectedSub = $subscriptions[$selectedSubIndices[0]]
        $script:AzureSelectedSubscriptions = @([PSCustomObject]@{
            Id   = $selectedSub.Id
            Name = $selectedSub.Name
        })

        Set-AzContext -SubscriptionId $selectedSub.Id -ErrorAction SilentlyContinue | Out-Null

    } catch {
        Write-Host "❌ Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        [Console]::ReadKey($true) | Out-Null
        return
    }

    # Main Azure PIM loop - using same UI pattern as Entra
    $script:AzureCurrentUserId = (Get-AzContext).Account.Id
    Start-AzurePIMRoleManagement
}

function Show-AzurePIMHeader {
    Write-Host "[ A Z U R E   P I M ]" -ForegroundColor Cyan
}

function Invoke-AzurePIMExit {
    param(
        [string]$Message = "Exiting..."
    )

    [Console]::CursorVisible = $true
    Clear-Host
    Write-Host $Message -ForegroundColor Yellow

    try {
        Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
        Write-Host "✅ Disconnected from Azure." -ForegroundColor Green
    } catch {
        Write-Host "ℹ️ Already disconnected from Azure." -ForegroundColor DarkGray
    }

    Write-Host "Terminal will close in 2 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    [Environment]::Exit(0)
}

function Show-AzureCheckboxMenu {
    param(
        [array]$Items,
        [string]$Title = "Select Items",
        [string]$Prompt = "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:",
        [switch]$SingleSelection = $false
    )

    if ($Items.Count -eq 0) {
        Write-Host "No items to select from." -ForegroundColor Red
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
            Show-AzurePIMHeader
            Write-Host ""
            Write-Host $Title -ForegroundColor Cyan
            Write-Host $("=" * $Title.Length) -ForegroundColor Cyan
            Write-Host ""

            for ($i = 0; $i -lt $Items.Count; $i++) {
                $item = $Items[$i]
                $checkbox = if ($selected[$i]) { "[✓]" } else { "[ ]" }
                $arrow = if ($i -eq $currentIndex) { "► " } else { "  " }
                $line = "$arrow$checkbox $item"

                if ($selected[$i]) {
                    Write-Host $line -ForegroundColor Green
                } else {
                    Write-Host $line -ForegroundColor White
                }
            }

            Write-Host ""
            $selectedCount = ($selected.GetEnumerator() | Where-Object { $_.Value }).Count
            $menuText = if ($Title -eq "🔄 Choose Action") { "Workflow Selected: $selectedCount" } else { "Roles Selected: $selectedCount" }
            Write-Host $menuText -ForegroundColor Cyan
            Write-Host ""

            if ($SingleSelection) {
                Write-Host "↑/↓ Navigate | SPACE Select | ENTER Confirm | $(Get-HelpShortcutText) | $(Get-QuitShortcutText)" -ForegroundColor Magenta
            } else {
                Write-Host "↑/↓ Navigate | SPACE Toggle | Ctrl+A Select All | ENTER Confirm | $(Get-HelpShortcutText) | $(Get-QuitShortcutText)" -ForegroundColor Magenta
            }

            $key = [Console]::ReadKey($true)

            # Handle Ctrl+Q to exit
            if (Test-QuitShortcut -Key $key) {
                Invoke-AzurePIMExit
            }

            # Handle Ctrl+A to select all
            if ($key.Modifiers -band [ConsoleModifiers]::Control -and $key.Key -eq 'A' -and -not $SingleSelection) {
                $allSelected = ($selected.Values | Where-Object { $_ }).Count -eq $Items.Count
                for ($i = 0; $i -lt $Items.Count; $i++) {
                    $selected[$i] = -not $allSelected
                }
                continue
            }

            # Handle Ctrl+H for help
            if (Test-HelpShortcut -Key $key) {
                Show-HelpMenu
                continue
            }

            switch ($key.Key) {
                "UpArrow" {
                    $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $Items.Count - 1 }
                }
                "DownArrow" {
                    $currentIndex = if ($currentIndex -lt ($Items.Count - 1)) { $currentIndex + 1 } else { 0 }
                }
                "Spacebar" {
                    if ($SingleSelection) {
                        for ($i = 0; $i -lt $Items.Count; $i++) {
                            $selected[$i] = $false
                        }
                        $selected[$currentIndex] = $true
                    } else {
                        $selected[$currentIndex] = -not $selected[$currentIndex]
                    }
                }
                "Enter" {
                    $selectedItems = @()
                    for ($i = 0; $i -lt $Items.Count; $i++) {
                        if ($selected[$i]) {
                            $selectedItems += $i
                        }
                    }
                    [Console]::CursorVisible = $true
                    return $selectedItems
                }
                "Escape" {
                    [Console]::CursorVisible = $true
                    return @()
                }
            }

        } while ($true)
    } finally {
        [Console]::CursorVisible = $true
    }
}

function Start-AzurePIMRoleManagement {
    [Console]::CursorVisible = $false

    # Always show both options - same as Entra workflow
    $menuItems = @(
        "Activate Roles",
        "Deactivate Roles"
    )

    # Show action menu using Azure checkbox menu
    $selectedIndices = Show-AzureCheckboxMenu -Items $menuItems -Title "🔄 Choose Action" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -SingleSelection

    if ($null -eq $selectedIndices -or $selectedIndices.Count -eq 0) {
        return
    }

    $selectedIndex = $selectedIndices[0]
    $selectedAction = $menuItems[$selectedIndex]

    [Console]::CursorVisible = $false

    if ($selectedAction -eq "Activate Roles") {
        # Show loading message, then load roles - same as Entra
        Clear-Host
        Show-AzurePIMHeader
        Write-Host ""
        Write-Host "🔄 Loading eligible roles..." -ForegroundColor Cyan -NoNewline

        $eligibleRoles = Get-AzureEligibleRoles
        $activeRoles = Get-AzureActiveRoles

        # Filter out already active roles from eligible
        $activeKeys = $activeRoles | ForEach-Object { "$($_.RoleDefinitionId)|$($_.Scope)" }
        $availableForActivation = @($eligibleRoles | Where-Object {
            $key = "$($_.RoleDefinitionId)|$($_.Scope)"
            $activeKeys -notcontains $key
        })

        if ($availableForActivation.Count -gt 0) {
            Write-Host " ✅ $($availableForActivation.Count) found" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host ""
        }

        Start-AzureRoleActivationWorkflow -EligibleRoles $availableForActivation -ActiveRoles $activeRoles

    } elseif ($selectedAction -eq "Deactivate Roles") {
        # Show loading message, then load roles - same as Entra
        Clear-Host
        Show-AzurePIMHeader
        Write-Host ""
        Write-Host "🔄 Loading active roles..." -ForegroundColor Cyan -NoNewline

        $activeRoles = Get-AzureActiveRoles

        if ($activeRoles.Count -gt 0) {
            Write-Host " ✅ $($activeRoles.Count) found" -ForegroundColor Green
        } else {
            Write-Host ""
        }

        Start-AzureRoleDeactivationWorkflow -ActiveRoles $activeRoles
    }
}

function Start-AzureRoleActivationWorkflow {
    param(
        [array]$EligibleRoles,
        [array]$ActiveRoles
    )

    if ($EligibleRoles.Count -eq 0) {
        Clear-Host
        Show-AzurePIMHeader
        Write-Host ""
        Write-Host "❌ No eligible roles available for activation." -ForegroundColor Red
        Write-Host ""

        if ($ActiveRoles.Count -gt 0) {
            Write-Host "Would you like to deactivate roles instead? (Y/N): " -NoNewline -ForegroundColor Cyan

            # Show cursor for Y/N input
            [Console]::CursorVisible = $true

            # Store cursor position for inline input
            $promptLeft = [Console]::CursorLeft
            $promptTop = [Console]::CursorTop

            # Show control bar below the prompt with proper spacing
            Write-Host "`n"  # Add blank line after prompt
            Write-Host "Y/N to choose | $(Get-QuitShortcutText)" -ForegroundColor Magenta

            # Return cursor to inline position after the prompt (same line as Y/N question)
            [Console]::SetCursorPosition($promptLeft, $promptTop)

            $userInput = ""
            do {
                $key = [Console]::ReadKey($true)

                # Check for Ctrl+Q
                if (Test-QuitShortcut -Key $key) {
                    Invoke-AzurePIMExit
                    return
                }

                # Handle Enter key
                if ($key.Key -eq 'Enter') {
                    if ($userInput -eq 'Y') {
                        Start-AzureRoleDeactivation -ActiveRoles $ActiveRoles
                        return
                    } elseif ($userInput -eq 'N') {
                        # Show no workflows message
                        Clear-Host
                        Show-AzurePIMHeader
                        Write-Host ""
                        Write-Host "❌ No role management workflows available." -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "Check back later when roles are approved or activated." -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

                        [Console]::CursorVisible = $false
                        do {
                            $k = [Console]::ReadKey($true)
                            if (Test-QuitShortcut -Key $k) {
                                Invoke-AzurePIMExit
                            }
                        } while ($true)
                        return
                    } else {
                        # Invalid input - show message
                        Write-Host ""
                        Write-Host "Please enter Y or N: " -NoNewline -ForegroundColor Yellow
                        $promptLeft = [Console]::CursorLeft
                        $promptTop = [Console]::CursorTop
                        Write-Host "`n"
                        Write-Host "Y/N to choose | $(Get-QuitShortcutText)" -ForegroundColor Magenta
                        [Console]::SetCursorPosition($promptLeft, $promptTop)
                        $userInput = ""
                    }
                }
                # Handle backspace
                elseif ($key.Key -eq 'Backspace' -and $userInput.Length -gt 0) {
                    $userInput = $userInput.Substring(0, $userInput.Length - 1)
                    Write-Host "`b `b" -NoNewline
                }
                # Handle regular characters (Y/N only)
                elseif ($key.KeyChar -match '[YyNn]' -and $userInput.Length -eq 0) {
                    $userInput = $key.KeyChar.ToString().ToUpper()
                    Write-Host $userInput -NoNewline -ForegroundColor Green
                }
            } while ($true)
        } else {
            Write-Host "❌ No role management workflows available." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Check back later when roles are approved or activated." -ForegroundColor Gray
            Write-Host ""
            Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

            # Wait for Ctrl+Q to exit
            do {
                $key = [Console]::ReadKey($true)
                if (Test-QuitShortcut -Key $key) {
                    Invoke-AzurePIMExit
                }
            } while ($true)
        }
        return
    }

    # Continue to role selection
    Show-AzureRoleActivationUI -EligibleRoles $EligibleRoles
}

function Start-AzureRoleDeactivationWorkflow {
    param([array]$ActiveRoles)

    if ($ActiveRoles.Count -eq 0) {
        Clear-Host
        Show-AzurePIMHeader
        Write-Host ""
        Write-Host "❌ No active roles available for deactivation." -ForegroundColor Red
        Write-Host ""

        # Check if there are eligible roles to offer activation
        $eligibleRoles = Get-AzureEligibleRoles
        if ($eligibleRoles.Count -gt 0) {
            Write-Host "Would you like to activate roles instead? (Y/N): " -NoNewline -ForegroundColor Cyan

            # Show cursor for Y/N input
            [Console]::CursorVisible = $true

            # Store cursor position for inline input
            $promptLeft = [Console]::CursorLeft
            $promptTop = [Console]::CursorTop

            # Show control bar below the prompt with proper spacing
            Write-Host "`n"  # Add blank line after prompt
            Write-Host "Y/N to choose | $(Get-QuitShortcutText)" -ForegroundColor Magenta

            # Return cursor to inline position after the prompt (same line as Y/N question)
            [Console]::SetCursorPosition($promptLeft, $promptTop)

            $userInput = ""
            do {
                $key = [Console]::ReadKey($true)

                # Check for Ctrl+Q
                if (Test-QuitShortcut -Key $key) {
                    Invoke-AzurePIMExit
                    return
                }

                # Handle Enter key
                if ($key.Key -eq 'Enter') {
                    if ($userInput -eq 'Y') {
                        Show-AzureRoleActivationUI -EligibleRoles $eligibleRoles
                        return
                    } elseif ($userInput -eq 'N') {
                        # Show no workflows message
                        Clear-Host
                        Show-AzurePIMHeader
                        Write-Host ""
                        Write-Host "❌ No role management workflows available." -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "Check back later when roles are approved or activated." -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

                        [Console]::CursorVisible = $false
                        do {
                            $k = [Console]::ReadKey($true)
                            if (Test-QuitShortcut -Key $k) {
                                Invoke-AzurePIMExit
                            }
                        } while ($true)
                        return
                    } else {
                        # Invalid input - show message
                        Write-Host ""
                        Write-Host "Please enter Y or N: " -NoNewline -ForegroundColor Yellow
                        $promptLeft = [Console]::CursorLeft
                        $promptTop = [Console]::CursorTop
                        Write-Host "`n"
                        Write-Host "Y/N to choose | $(Get-QuitShortcutText)" -ForegroundColor Magenta
                        [Console]::SetCursorPosition($promptLeft, $promptTop)
                        $userInput = ""
                    }
                }
                # Handle backspace
                elseif ($key.Key -eq 'Backspace' -and $userInput.Length -gt 0) {
                    $userInput = $userInput.Substring(0, $userInput.Length - 1)
                    Write-Host "`b `b" -NoNewline
                }
                # Handle regular characters (Y/N only)
                elseif ($key.KeyChar -match '[YyNn]' -and $userInput.Length -eq 0) {
                    $userInput = $key.KeyChar.ToString().ToUpper()
                    Write-Host $userInput -NoNewline -ForegroundColor Green
                }
            } while ($true)
        } else {
            Write-Host "❌ No role management workflows available." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Check back later when roles are approved or activated." -ForegroundColor Gray
            Write-Host ""
            Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

            # Wait for Ctrl+Q to exit
            do {
                $key = [Console]::ReadKey($true)
                if (Test-QuitShortcut -Key $key) {
                    Invoke-AzurePIMExit
                }
            } while ($true)
        }
        return
    }

    # Continue to role selection
    Start-AzureRoleDeactivation -ActiveRoles $ActiveRoles
}

function Show-AzureRoleActivationUI {
    param([array]$EligibleRoles)

    # Build role items with friendly display names (includes scope - Azure specific)
    $roleItems = @()
    foreach ($role in $EligibleRoles) {
        $friendlyScope = $role.ScopeDisplayName
        if ($role.ScopeDisplayName -match '/subscriptions/[^/]+/resourceGroups/([^/]+)') {
            $friendlyScope = $Matches[1]
        } elseif ($role.ScopeDisplayName -match '/subscriptions/[^/]+$') {
            $friendlyScope = "Subscription"
        }
        $roleItems += "$($role.RoleDisplayName) - $friendlyScope"
    }

    # Show role selection using Azure checkbox menu
    $selectedIndices = Show-AzureCheckboxMenu -Items $roleItems -Title "Select Roles to Activate" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:"

    if ($null -eq $selectedIndices -or $selectedIndices.Count -eq 0) {
        return
    }

    # Get selected roles
    $rolesToActivate = @()
    foreach ($idx in $selectedIndices) {
        $rolesToActivate += $EligibleRoles[$idx]
    }

    # Run activation wizard
    Show-AzureActivationWizard -RolesToActivate $rolesToActivate
}

function Show-AzureDeactivationCountdown {
    param([array]$TooNewRoles)

    try {
        [Console]::CursorVisible = $false

        Clear-Host
        Show-AzurePIMHeader
        Write-Host ""
        Write-Host "⏰ Time Remaining Until Roles Can Be Deactivated" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   (5-minute minimum activation period required)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   The deactivation menu will automatically refresh when timers expire" -ForegroundColor Cyan
        Write-Host ""

        # Remember the starting line for roles
        $roleStartLine = [Console]::CursorTop

        # Deduplicate roles by name
        $uniqueRoles = @{}
        $deduplicatedRoles = @()
        foreach ($roleInfo in $TooNewRoles) {
            if (-not $uniqueRoles.ContainsKey($roleInfo.RoleName)) {
                $uniqueRoles[$roleInfo.RoleName] = $true
                $deduplicatedRoles += $roleInfo
            }
        }

        # Show initial role lines
        foreach ($roleInfo in $deduplicatedRoles) {
            Write-Host "  ⏳ $($roleInfo.RoleName): --:-- remaining" -ForegroundColor Cyan
        }
        Write-Host ""
        Write-Host "Ctrl+Q to exit" -ForegroundColor Magenta

        do {
            $allReady = $true

            # Update each role's countdown in place
            for ($i = 0; $i -lt $deduplicatedRoles.Count; $i++) {
                $roleInfo = $deduplicatedRoles[$i]
                try {
                    $activationTime = $roleInfo.ActivationTime
                    $deactivationTime = $activationTime.AddMinutes(5)
                    $timeRemaining = $deactivationTime - (Get-Date)

                    # Position cursor at this role's line
                    $lineNumber = $roleStartLine + $i
                    [Console]::SetCursorPosition(0, $lineNumber)

                    if ($timeRemaining.TotalSeconds -gt 0) {
                        $allReady = $false
                        $minutes = [int][math]::Floor($timeRemaining.TotalMinutes)
                        $seconds = [int][math]::Floor($timeRemaining.TotalSeconds % 60)
                        $timeDisplay = "{0:D2}:{1:D2}" -f $minutes, $seconds

                        Write-Host "  ⏳ $($roleInfo.RoleName): $timeDisplay remaining" -ForegroundColor Cyan -NoNewline
                        Write-Host (" " * ([Console]::WindowWidth - [Console]::CursorLeft - 1))
                    } else {
                        Write-Host "  ✅ $($roleInfo.RoleName): Ready for deactivation!" -ForegroundColor Green -NoNewline
                        Write-Host (" " * ([Console]::WindowWidth - [Console]::CursorLeft - 1))
                    }
                } catch {
                    $lineNumber = $roleStartLine + $i
                    [Console]::SetCursorPosition(0, $lineNumber)
                    Write-Host (" " * ([Console]::WindowWidth - 1)) -NoNewline
                    [Console]::SetCursorPosition(0, $lineNumber)
                    Write-Host "  ❓ $($roleInfo.RoleName): Unable to check" -ForegroundColor Yellow
                }
            }

            # Check if user pressed a key
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if (Test-QuitShortcut -Key $key) {
                    Invoke-AzurePIMExit
                }
            }

            if (-not $allReady) {
                Start-Sleep -Seconds 1
            }

        } while (-not $allReady)

        [Console]::CursorVisible = $false
        return $true
    } catch {
        Write-Host "Error in countdown: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Start-AzureRoleDeactivation {
    param([array]$ActiveRoles)

    # Check for roles that are too new to deactivate (5-minute rule)
    $readyToDeactivate = @()
    $tooNewRoles = @()

    foreach ($role in $ActiveRoles) {
        try {
            if ($role.StartDateTime) {
                $activationTime = [DateTime]::Parse($role.StartDateTime).ToLocalTime()
                $timeSinceActivation = (Get-Date) - $activationTime

                if ($timeSinceActivation.TotalMinutes -lt 5) {
                    $tooNewRoles += [PSCustomObject]@{
                        RoleName       = $role.RoleDisplayName
                        ActivationTime = $activationTime
                        Role           = $role
                    }
                } else {
                    $readyToDeactivate += $role
                }
            } else {
                # No activation time available, assume it's ready
                $readyToDeactivate += $role
            }
        } catch {
            # If error checking, assume it's ready
            $readyToDeactivate += $role
        }
    }

    # If some roles are too new, show countdown
    if ($tooNewRoles.Count -gt 0) {
        [Console]::CursorVisible = $false
        Clear-Host
        Show-AzurePIMHeader
        Write-Host ""

        if ($readyToDeactivate.Count -eq 0) {
            Write-Host "⏰ All roles are within the 5-minute activation period." -ForegroundColor Yellow
        } else {
            Write-Host "⏰ Some roles are within the 5-minute activation period." -ForegroundColor Yellow
        }
        Write-Host "Showing countdown until they can be deactivated..." -ForegroundColor Cyan
        Write-Host ""

        $countdownResult = Show-AzureDeactivationCountdown -TooNewRoles $tooNewRoles

        if ($countdownResult -eq $true) {
            # Refresh active roles and restart deactivation
            Start-AzureRoleDeactivation -ActiveRoles $ActiveRoles
        }
        return
    }

    # Build role items with friendly display names (includes scope - Azure specific)
    $roleItems = @()
    foreach ($role in $readyToDeactivate) {
        $friendlyScope = $role.ScopeDisplayName
        if ($role.ScopeDisplayName -match '/subscriptions/[^/]+/resourceGroups/([^/]+)') {
            $friendlyScope = $Matches[1]
        } elseif ($role.ScopeDisplayName -match '/subscriptions/[^/]+$') {
            $friendlyScope = "Subscription"
        }
        $roleItems += "$($role.RoleDisplayName) - $friendlyScope"
    }

    # Show role selection using Azure checkbox menu
    $selectedIndices = Show-AzureCheckboxMenu -Items $roleItems -Title "Select Roles to Deactivate" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:"

    if ($null -eq $selectedIndices -or $selectedIndices.Count -eq 0) {
        return
    }

    # Get selected roles
    $rolesToDeactivate = @()
    foreach ($idx in $selectedIndices) {
        $rolesToDeactivate += $readyToDeactivate[$idx]
    }

    # Deactivate roles
    Clear-Host
    Show-AzurePIMHeader
    Write-Host ""
    Write-Host "🔄 Deactivating $($rolesToDeactivate.Count) role(s)..." -ForegroundColor Cyan
    Write-Host ""

    $successCount = 0
    $failCount = 0

    foreach ($role in $rolesToDeactivate) {
        Write-Host "  Deactivating $($role.RoleDisplayName)..." -NoNewline -ForegroundColor Cyan
        $result = Stop-AzureRoleActivation -ActiveRole $role
        if ($result) {
            Write-Host " ✓" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host " ✗" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host ""
    if ($successCount -gt 0) {
        Write-Host "✅ Successfully deactivated $successCount role(s)" -ForegroundColor Green
    }
    if ($failCount -gt 0) {
        Write-Host "❌ Failed to deactivate $failCount role(s)" -ForegroundColor Red
    }

    Write-Host ""

    # Ask if user wants to manage more roles - same as Entra workflow
    do {
        [Console]::CursorVisible = $true
        $userInput = Read-PIMInput -Prompt "Would you like to manage more roles? (Y/N)" -ControlsText $script:ControlMessages['Exit']
        if (-not $userInput) { continue }
        $userInput = $userInput.Trim().ToUpper()
        if ($userInput -eq "Y" -or $userInput -eq "YES") {
            $continueChoice = "Yes"
            break
        } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
            $continueChoice = "No"
            break
        } else {
            Write-Host "Please enter Y or N." -ForegroundColor Yellow
        }
    } while ($true)

    if ($continueChoice -eq "Yes") {
        # Return to main workflow selector (Entra/Azure choice)
        return
    } else {
        Write-Host "No additional roles will be managed." -ForegroundColor Red
        Write-Host ""
        Write-Host "Please close the terminal." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

        # Hide cursor and wait for user to exit with Ctrl+Q
        [Console]::CursorVisible = $false
        do {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if (Test-QuitShortcut -Key $key) {
                    Invoke-AzurePIMExit
                    return
                }
            }
            Start-Sleep -Milliseconds 100
        } while ($true)
    }
}

function Show-AzureActivationWizard {
    param(
        [array]$RolesToActivate
    )

    # Clear screen and show header - same as Entra workflow
    Clear-Host
    Show-AzurePIMHeader
    Write-Host ""

    # Duration input - same as Entra workflow
    do {
        $durationInput = Read-PIMInput -Prompt "Enter activation duration (e.g., 1H, 30M, 2H30M)" -ControlsText $script:ControlMessages['Input']

        if ([string]::IsNullOrWhiteSpace($durationInput) -or $durationInput -notmatch '^\d+[HM]') {
            Write-Host "ERROR: Invalid format. Use '1H', '30M', or '2H30M'." -ForegroundColor Red
        }
    } while ([string]::IsNullOrWhiteSpace($durationInput) -or $durationInput -notmatch '^\d+[HM]')

    # Convert duration to ISO 8601 format
    $duration = $durationInput.ToUpper() -replace '(\d+)H', 'PT${1}H' -replace '(\d+)M', '${1}M'
    if ($duration -match '^\d+M$') { $duration = "PT$duration" }

    # Parse duration to check if it's less than 5 minutes
    $totalMinutes = 0
    if ($durationInput.ToUpper() -match '(\d+)H') { $totalMinutes += [int]$matches[1] * 60 }
    if ($durationInput.ToUpper() -match '(\d+)M') { $totalMinutes += [int]$matches[1] }

    if ($totalMinutes -lt 5) {
        Write-Host ""
        Write-Host "❌ Activation Duration too short: Minimum Required is 5 minutes." -ForegroundColor Red
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Yellow
        $null = [Console]::ReadKey($true)
        return $false
    }

    # Justification input - same as Entra workflow
    $justification = Read-PIMInput -Prompt "Enter reason for activation" -ControlsText $script:ControlMessages['Input']

    if ([string]::IsNullOrWhiteSpace($justification)) {
        Write-Host "Justification is required." -ForegroundColor Red
        return $false
    }

    Write-Host "🔄 Activating $($RolesToActivate.Count) role(s)..." -ForegroundColor Cyan
    Write-Host ""

    $successCount = 0
    $failCount = 0

    foreach ($role in $RolesToActivate) {
        $roleName = $role.RoleDisplayName
        Write-Host "  Activating $roleName..." -NoNewline -ForegroundColor Cyan
        $result = Start-AzureRoleActivation -EligibleRole $role -Justification $justification -Duration $duration
        if ($result) {
            Write-Host " ✓" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host " ✗" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host ""
    if ($successCount -gt 0) {
        Write-Host "✅ Successfully activated $successCount role(s)" -ForegroundColor Green
    }
    if ($failCount -gt 0) {
        Write-Host "❌ Failed to activate $failCount role(s)" -ForegroundColor Red
    }

    Write-Host ""

    # Ask if user wants to manage more roles - same as Entra workflow
    do {
        [Console]::CursorVisible = $true
        $userInput = Read-PIMInput -Prompt "Would you like to manage more roles? (Y/N)" -ControlsText $script:ControlMessages['Exit']
        if (-not $userInput) { continue }
        $userInput = $userInput.Trim().ToUpper()
        if ($userInput -eq "Y" -or $userInput -eq "YES") {
            $continueChoice = "Yes"
            break
        } elseif ($userInput -eq "N" -or $userInput -eq "NO") {
            $continueChoice = "No"
            break
        } else {
            Write-Host "Please enter Y or N." -ForegroundColor Yellow
        }
    } while ($true)

    if ($continueChoice -eq "Yes") {
        # Return to main workflow selector (Entra/Azure choice)
        return
    } else {
        Write-Host "No additional roles will be managed." -ForegroundColor Red
        Write-Host ""
        Write-Host "Please close the terminal." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

        # Hide cursor and wait for user to exit with Ctrl+Q
        [Console]::CursorVisible = $false
        do {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if (Test-QuitShortcut -Key $key) {
                    Invoke-AzurePIMExit
                    return
                }
            }
            Start-Sleep -Milliseconds 100
        } while ($true)
    }

    return $true
}

function Start-EntraPIMWorkflow {
    $script:CurrentWorkflow = 'Entra'

    # Pre-load MSAL and compile helper BEFORE Graph modules load their own MSAL
    $msalInitialized = Initialize-MSALAssemblies
    if ($msalInitialized) {
        try {
            $null = Initialize-MSALHelper
        } catch {
            Write-Host "MSAL Helper compile error: $($_.Exception.Message)" -ForegroundColor Red
            $msalInitialized = $false
        }
    }

    $requiredGraphModules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Identity.DirectoryManagement",
        "Microsoft.Graph.Identity.Governance"
    )

    Write-Host "Loading Microsoft Graph modules..." -ForegroundColor Cyan
    Write-Host ""

    $barWidth = 30
    $currentModule = 0
    $totalModules = $requiredGraphModules.Count

    foreach ($module in $requiredGraphModules) {
        $currentModule++
        $percent = [math]::Floor(($currentModule / $totalModules) * 100)
        $filled = [math]::Floor(($currentModule / $totalModules) * $barWidth)
        $empty = $barWidth - $filled
        $bar = "█" * $filled + "░" * $empty

        Write-Host "  [$bar] $percent% " -NoNewline -ForegroundColor Yellow
        Write-Host "Loading: " -NoNewline -ForegroundColor Gray
        Write-Host "$module" -ForegroundColor White

        try {
            Import-Module $module -Force -ErrorAction Stop
            if (-not (Get-Module -Name $module)) {
                throw "Module $module did not load properly"
            }
        } catch {
            Write-Host "  ❌ Failed to load $module : $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Run: Install-Module $module -Scope CurrentUser -Force" -ForegroundColor Yellow
            return
        }
    }

    Write-Host ""
    Write-Host "  ✓ All modules ready!" -ForegroundColor Green
    Write-Host ""

    # Authenticate to Microsoft Graph
    [Console]::CursorVisible = $false

    try {
        $scopes = @('RoleManagement.ReadWrite.Directory', 'Directory.Read.All')
        $connected = Connect-MgGraphWithBrowser -Scopes $scopes

        if (-not $connected) {
            Write-Host "❌ Failed to connect to Microsoft Graph" -ForegroundColor Red
            Write-Host "Press Enter to exit..." -ForegroundColor Yellow
            Read-Host
            return
        }

        Write-Host "✅ Successfully connected to Microsoft Graph" -ForegroundColor Green

        $currentUser = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/me" -ErrorAction Stop
        $currentUserId = $currentUser.id
        Write-Host "✅ Current User ID: $currentUserId" -ForegroundColor Green

        Initialize-RoleDefinitionCache
    } catch {
        Write-Host "❌ Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Press Enter to continue..." -ForegroundColor Yellow
        Read-Host
        return
    }

    # Start the PIM role management workflow
    [Console]::CursorVisible = $true
    Start-PIMRoleManagement -CurrentUserId $currentUserId

    # Cleanup
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

# ========================= Main Entry Point =========================

do {
    $workflow = Show-WorkflowSelector

    switch ($workflow) {
        'Entra' {
            Start-EntraPIMWorkflow
        }
        'Azure' {
            Start-AzurePIMWorkflow
        }
        'Quit' {
            Clear-Host
            Write-Host "Goodbye!" -ForegroundColor Cyan
            [Environment]::Exit(0)
        }
    }
} while ($true)