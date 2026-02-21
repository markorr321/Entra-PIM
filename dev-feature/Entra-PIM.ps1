# ========================= Script Parameters =========================
param(
    [Parameter(HelpMessage = "Client ID of the app registration to use for delegated auth")]
    [string]$ClientId,

    [Parameter(HelpMessage = "Tenant ID to use with the specified app registration")]
    [string]$TenantId
)

# Store parameters at script scope for use in authentication functions
$script:CustomClientId = $ClientId
$script:CustomTenantId = $TenantId

# ========================= Cross-Platform Keyboard Shortcuts =========================
# Detect if running on macOS (use built-in $IsMacOS variable if available)
$script:IsRunningOnMac = if ($null -ne $IsMacOS) { $IsMacOS } else { $PSVersionTable.OS -match 'Darwin' }

# Enable Ctrl+C as input on macOS/Linux (prevents SIGINT from terminating the script)
# This must be set before any [Console]::ReadKey() calls
if ($script:IsRunningOnMac -or ($null -ne $IsLinux -and $IsLinux)) {
    [Console]::TreatControlCAsInput = $true
    # Clear any buffered input that may have been queued when setting TreatControlCAsInput
    Start-Sleep -Milliseconds 100
    while ([Console]::KeyAvailable) {
        $null = [Console]::ReadKey($true)
    }
}

# Cross-platform shortcut detection
function Test-CancelShortcut {
    param([System.ConsoleKeyInfo]$Key)

    # Ctrl+C for cancel/exit on all platforms
    return ($Key.Key -eq 'C' -and ($Key.Modifiers -band [ConsoleModifiers]::Control))
}

function Test-QuitShortcut {
    param([System.ConsoleKeyInfo]$Key)

    # Ctrl+Q works on both macOS and Windows
    # Also accept Ctrl+C as quit shortcut (especially important for macOS)
    return (($Key.Key -eq 'Q' -and ($Key.Modifiers -band [ConsoleModifiers]::Control)) -or
            ($Key.Key -eq 'C' -and ($Key.Modifiers -band [ConsoleModifiers]::Control)))
}

function Test-HelpShortcut {
    param([System.ConsoleKeyInfo]$Key)

    if ($script:IsRunningOnMac) {
        # On macOS: Ctrl+H sends Backspace with Control modifier
        return ($Key.Key -eq 'Backspace' -and ($Key.Modifiers -band [ConsoleModifiers]::Control))
    } else {
        # On Windows: Ctrl+H works normally
        return ($Key.Key -eq 'H' -and ($Key.Modifiers -band [ConsoleModifiers]::Control))
    }
}

function Get-HelpShortcutText {
    return "Ctrl+H Help"
}

function Get-QuitShortcutText {
    return "Ctrl+Q Exit"
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
        $alreadyLoaded = $loadedAssembliesCheck | Where-Object { $_.GetName().Name -eq 'Microsoft.IdentityModel.Abstractions' } | Select-Object -First 1
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
    $alreadyLoaded = $loadedAssembliesCheck | Where-Object { $_.GetName().Name -eq 'Microsoft.Identity.Client' } | Select-Object -First 1
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
    $referencedAssemblies += @("netstandard", "System.Linq", "System.Threading.Tasks", "System.Collections")

    # C# code for browser-based authentication (no WAM)
    $code = @"
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Identity.Client;

public class PIMBrowserAuth
{
    public static string GetAccessToken(string clientId, string[] scopes, string tenantId = null)
    {
        return GetAccessTokenWithClaims(clientId, scopes, null, tenantId);
    }

    public static string GetAccessTokenWithClaims(string clientId, string[] scopes, string claims, string tenantId = null)
    {
        try
        {
            var task = Task.Run(async () => await GetAccessTokenAsync(clientId, scopes, claims, tenantId));
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

    private static async Task<string> GetAccessTokenAsync(string clientId, string[] scopes, string claims, string tenantId)
    {
        // Use system browser with localhost redirect - must match app registration
        var builder = PublicClientApplicationBuilder.Create(clientId)
            .WithRedirectUri("http://localhost");

        // Add tenant ID if provided (for dedicated app registrations)
        // This enforces the tenant at the authority level
        if (!string.IsNullOrEmpty(tenantId))
        {
            builder = builder.WithAuthority($"https://login.microsoftonline.com/{tenantId}");
        }

        IPublicClientApplication publicClientApp = builder.Build();

        using (var cts = new CancellationTokenSource(TimeSpan.FromSeconds(180)))
        {
            var tokenBuilder = publicClientApp.AcquireTokenInteractive(scopes)
                .WithPrompt(Prompt.SelectAccount)
                .WithUseEmbeddedWebView(false)
                .WithSystemWebViewOptions(new SystemWebViewOptions());
            
            // Add extra query parameters to hint at the tenant
            if (!string.IsNullOrEmpty(tenantId))
            {
                tokenBuilder = tokenBuilder.WithExtraQueryParameters($"domain_hint={tenantId}");
            }

            // Add claims challenge if provided (for Conditional Access step-up)
            if (!string.IsNullOrEmpty(claims))
            {
                tokenBuilder = tokenBuilder.WithClaims(claims);
            }

            var result = await tokenBuilder
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

    # Use custom ClientId if provided, otherwise use Microsoft's well-known PowerShell public client ID
    $clientId = if ($script:CustomClientId) { $script:CustomClientId } else { "14d82eec-204b-4c2f-b7e8-296a70dab67e" }
    $tenantId = $script:CustomTenantId  # May be null, which is fine

    # Build scopes string for Graph
    $scopeArray = $Scopes | ForEach-Object {
        if ($_ -notlike "https://*") { "https://graph.microsoft.com/$_" } else { $_ }
    }

    $accessToken = [PIMBrowserAuth]::GetAccessToken($clientId, $scopeArray, $tenantId)
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

    # Use custom ClientId if provided, otherwise use Microsoft's well-known PowerShell public client ID
    $clientId = if ($script:CustomClientId) { $script:CustomClientId } else { "14d82eec-204b-4c2f-b7e8-296a70dab67e" }
    $tenantId = $script:CustomTenantId  # May be null, which is fine

    # Build scopes string for Graph
    $scopeArray = $Scopes | ForEach-Object {
        if ($_ -notlike "https://*") { "https://graph.microsoft.com/$_" } else { $_ }
    }

    $accessToken = [PIMBrowserAuth]::GetAccessTokenWithClaims($clientId, $scopeArray, $Claims, $tenantId)
    return $accessToken
}

function Get-AzureBrowserAccessTokenWithClaims {
    <#
    .SYNOPSIS
        Gets an Azure management access token with claims challenge for Conditional Access step-up authentication.
    #>
    param(
        [string]$Claims
    )

    # Ensure MSAL helper is compiled
    if (-not $script:MSALHelperCompiled) {
        $null = Initialize-MSALHelper
    }

    # Azure PowerShell client ID and management scope
    $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    $scopes = @("https://management.azure.com/.default")
    $tenantId = $script:CustomTenantId  # May be null, which is fine

    $accessToken = [PIMBrowserAuth]::GetAccessTokenWithClaims($clientId, $scopes, $Claims, $tenantId)
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

        # Show which app registration is being used
        if ($script:CustomClientId) {
            Write-Host "Using custom app registration..." -ForegroundColor Cyan
            Write-Host "  Client ID: $($script:CustomClientId)" -ForegroundColor Gray
            if ($script:CustomTenantId) {
                Write-Host "  Tenant ID: $($script:CustomTenantId)" -ForegroundColor Gray
            }
        } else {
            Write-Host "Using default Microsoft Graph authentication..." -ForegroundColor Cyan
        }

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
        # Handle Ctrl+C (especially important for macOS)
        if (Test-CancelShortcut -Key $key) {
            Invoke-PIMExit -Message "Operation cancelled..."
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
    # Use REST API for faster response
    try {
        $uri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances?`$filter=principalId eq '$CurrentUserId' and assignmentType eq 'Activated'&`$select=id,roleDefinitionId,principalId,directoryScopeId,startDateTime,endDateTime"
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        if ($response -and $response.value) {
            # Return objects with proper property names for compatibility
            return $response.value | ForEach-Object {
                [PSCustomObject]@{
                    Id = $_.id
                    RoleDefinitionId = $_.roleDefinitionId
                    PrincipalId = $_.principalId
                    DirectoryScopeId = $_.directoryScopeId
                    StartDateTime = $_.startDateTime
                    EndDateTime = $_.endDateTime
                }
            }
        }
        return @()
    } catch {
        return @()
    }
}

# OPTIMIZATION: Fast active role retrieval for deactivation workflow
function Get-ActiveRolesOptimized {
    param([string]$CurrentUserId)
    
    $activeRoles = @()
    try {
        # Use REST API for faster response - include all fields needed for deactivation
        $uri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances?`$filter=principalId eq '$CurrentUserId' and assignmentType eq 'Activated'&`$select=id,roleDefinitionId,principalId,directoryScopeId,startDateTime,endDateTime"
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        $scheduleInstances = if ($response -and $response.value) { $response.value } else { @() }
        
        # Use pre-loaded role definition cache for instant lookup
        foreach ($instance in $scheduleInstances) {
            $roleDefinition = Get-CachedRoleDefinition -RoleId $instance.roleDefinitionId
            if ($roleDefinition) {
                $expirationTime = $null
                if ($instance.endDateTime) {
                    $expirationTime = [DateTime]::Parse($instance.endDateTime, [System.Globalization.CultureInfo]::InvariantCulture).ToLocalTime()
                }
                
                $activeRoles += [PSCustomObject]@{
                    RoleName = $roleDefinition.DisplayName
                    Assignment = [PSCustomObject]@{
                        Id = $instance.id
                        RoleDefinitionId = $instance.roleDefinitionId
                        PrincipalId = $instance.principalId
                        DirectoryScopeId = $instance.directoryScopeId
                        StartDateTime = $instance.startDateTime
                        EndDateTime = $instance.endDateTime
                    }
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
        # Sequential API calls with timing
        $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
        
        $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
        $eligibilityResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilityScheduleInstances?`$filter=principalId eq '$CurrentUserId'&`$select=roleDefinitionId,principalId,directoryScopeId" -ErrorAction Stop
        $eligibilitySchedules = if ($eligibilityResponse -and $eligibilityResponse.value) { $eligibilityResponse.value } else { @() }
        $sw1.Stop()
        Write-Host " [E:$($sw1.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline
        
        $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $activeResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances?`$filter=principalId eq '$CurrentUserId'&`$select=roleDefinitionId,endDateTime,assignmentType" -ErrorAction Stop
            $activatedAssignments = if ($activeResponse -and $activeResponse.value) { $activeResponse.value } else { @() }
        } catch { $activatedAssignments = @() }
        $sw2.Stop()
        Write-Host " [A:$($sw2.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline
        
        $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $pendingResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests?`$filter=principalId eq '$CurrentUserId' and status eq 'PendingApproval'&`$select=roleDefinitionId" -ErrorAction Stop
        } catch { $pendingResponse = $null }
        $sw3.Stop()
        Write-Host " [P:$($sw3.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline
        
        # Process eligibility schedules with cached role definitions
        $sw4 = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ($schedule in $eligibilitySchedules) {
            $roleDef = Get-CachedRoleDefinition -RoleId $schedule.roleDefinitionId
            if ($roleDef) {
                $allEligibleRoles += [PSCustomObject]@{
                    RoleDefinitionId = $schedule.roleDefinitionId
                    RoleDefinition   = @{
                        DisplayName = $roleDef.DisplayName
                        Id = $roleDef.Id
                        Description = $roleDef.Description
                    }
                    PrincipalId      = $schedule.principalId
                    DirectoryScopeId = $schedule.directoryScopeId
                }
            }
        }
        $sw4.Stop()
        Write-Host " [C:$($sw4.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline
        
        # Process active and permanently assigned roles
        $activeRoleIds = @()
        if ($activatedAssignments -and $activatedAssignments.Count -gt 0) {
            $currentTime = Get-Date
            $activeRoleIds = $activatedAssignments | Where-Object {
                # Exclude permanent assignments (Assigned) and currently active PIM-activated roles
                $_.assignmentType -eq 'Assigned' -or
                ($null -ne $_.endDateTime -and [DateTime]::Parse($_.endDateTime, [System.Globalization.CultureInfo]::InvariantCulture).ToLocalTime() -gt $currentTime)
            } | Select-Object -ExpandProperty roleDefinitionId -Unique
        }
        
        # Process pending requests
        $pendingRoleIds = @()
        if ($pendingResponse -and $pendingResponse.value) {
            $pendingRoleIds = @($pendingResponse.value | Select-Object -ExpandProperty roleDefinitionId -Unique)
        }
        
        $swTotal.Stop()
        Write-Host " [T:$($swTotal.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray
    } catch {
        Write-Host " Err: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "[ E N T R A   P I M ]" -ForegroundColor Magenta
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

            # Calculate total display items (roles + back item)
            $backIndex = $activeRoleData.Count
            $totalDisplayItems = $activeRoleData.Count + 1

            if ($currentIndex -ge $totalDisplayItems) {
                $currentIndex = $totalDisplayItems - 1
            }

            # Display active roles with dynamic countdown
            for ($i = 0; $i -lt $activeRoleData.Count; $i++) {
                $roleInfo = $activeRoleData[$i]

                # Display role with selection indicator
                $checkbox = if ($selected[$i]) { "[✓]" } else { "[ ]" }
                $arrow = if ($i -eq $currentIndex) { "► " } else { "  " }

                Write-Host "$arrow$checkbox $($roleInfo.Role.RoleName) ($($roleInfo.CountdownText))" -ForegroundColor $(if ($i -eq $currentIndex) { "Yellow" } else { "White" })
            }

            # Show Back item
            $backArrow = if ($currentIndex -eq $backIndex) { "► " } else { "  " }
            $backColor = if ($currentIndex -eq $backIndex) { "Yellow" } else { "Gray" }
            Write-Host "$backArrow← Back" -ForegroundColor $backColor

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
                        if ($currentIndex -gt 0) { $currentIndex-- } else { $currentIndex = $totalDisplayItems - 1 }
                    }
                    "DownArrow" {
                        if ($currentIndex -lt ($totalDisplayItems - 1)) { $currentIndex++ } else { $currentIndex = 0 }
                    }
                    "Spacebar" {
                        if ($currentIndex -eq $backIndex) {
                            return "BACK"
                        }
                        $selected[$currentIndex] = -not $selected[$currentIndex]
                    }
                    "Enter" {
                        if ($currentIndex -eq $backIndex) {
                            return "BACK"
                        }
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
                        return "BACK"
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
                $activationTime = [DateTime]::Parse($assignment.StartDateTime, [System.Globalization.CultureInfo]::InvariantCulture).ToLocalTime()
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

    if ($selectedIndices -eq "BACK") {
        return
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

    if ($selectedIndices -eq "BACK") {
        return
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
        Write-Host "[ E N T R A   P I M ]" -ForegroundColor Magenta
        Write-Host "    with PowerShell" -ForegroundColor DarkGray
    }
    
    function Show-PIMGlobalHeaderMinimal {
        Write-Host "[ E N T R A   P I M ]" -ForegroundColor Magenta
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
        # Restore Ctrl+C default behavior before exiting
        [Console]::TreatControlCAsInput = $false
        Clear-Host
        Write-Host $Message -ForegroundColor Yellow
        
        try {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Write-Host "✅ Disconnected from Microsoft Graph." -ForegroundColor Green
        } catch {
            Write-Host "ℹ️ Already disconnected from Microsoft Graph." -ForegroundColor DarkGray
        }

        Write-Host ""
        exit 0
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

        # Handle Ctrl+C globally (especially important for macOS)
        if (Test-CancelShortcut -Key $Key) {
            Invoke-PIMExit -Message "Operation cancelled..."
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
        
        # Display prompt inline with cursor right after colon
        Write-Host "${Prompt}: " -ForegroundColor Cyan -NoNewline
        
        # Cursor is now right after ": ", ready for input
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
                continue
            }

            # Handle ESC for cancellation
            if ($key.Key -eq 'Escape') {
                Write-Host ""
                return $null
            }
            
            # Handle Enter
            if ($key.Key -eq 'Enter') {
                Write-Host ""  # Move to next line after input
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
            # Show checkbox menu for role selection with back option
            $selectedIndices = Show-CheckboxMenu -Items $roleItems -Title "Select Roles to Activate" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -ShowBack

            # Back returns to action menu
            if ($selectedIndices -eq "BACK") {
                return
            }

            if ($selectedIndices.Count -eq 0) {
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
                    startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
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
                        # Role has a pending activation request - check if it's actually active now
                        try {
                            $activeCheck = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -Filter "principalId eq '$CurrentUserId' and roleDefinitionId eq '$($role.RoleDefinitionId)'" -ErrorAction SilentlyContinue
                            if ($activeCheck) {
                                Write-Host "✅ Role activated: $roleName" -ForegroundColor Green
                                $successCount++
                            } else {
                                Write-Host "❌ Failed to activate: $roleName" -ForegroundColor Red
                                $failCount++
                            }
                        } catch {
                            Write-Host "❌ Failed to activate: $roleName" -ForegroundColor Red
                            $failCount++
                        }
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
                                $scopes = @(
                                    'RoleAssignmentSchedule.ReadWrite.Directory',
                                    'RoleEligibilitySchedule.ReadWrite.Directory',
                                    'RoleManagement.Read.Directory',
                                    'RoleManagementPolicy.Read.Directory'
                                )
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
        Write-Host "[ E N T R A   P I M ]" -ForegroundColor Magenta
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
                    $expirationTime = [DateTime]::Parse($schedule.ScheduleInfo.Expiration.EndDateTime, [System.Globalization.CultureInfo]::InvariantCulture).ToLocalTime()
                    
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
                    Write-Host "[ E N T R A   P I M ]" -ForegroundColor Magenta
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
        Write-Host "  ← Back" -ForegroundColor Gray
        Write-Host ""
        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

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

            # Check if user pressed a key
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if (Test-QuitShortcut -Key $key) {
                    Invoke-PIMExit
                } else {
                    # Any other key = go back
                    return "BACK"
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
        $totalRoleDisplayItems = $RoleItems.Count + 1  # +1 for Back item
        $backIndex = $RoleItems.Count
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

                # Show Back item in role selection step
                if ($currentStep -eq 0) {
                    $backArrow = if ($currentRoleIndex -eq $backIndex) { "► " } else { "  " }
                    $backColor = if ($currentRoleIndex -eq $backIndex) { "Yellow" } else { "Gray" }
                    Write-Host "$backArrow← Back" -ForegroundColor $backColor
                }

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
                            $currentRoleIndex = if ($currentRoleIndex -gt 0) { $currentRoleIndex - 1 } else { $totalRoleDisplayItems - 1 }
                        }
                    }
                    "DownArrow" {
                        if ($currentStep -eq 0) {
                            $currentRoleIndex = if ($currentRoleIndex -lt ($totalRoleDisplayItems - 1)) { $currentRoleIndex + 1 } else { 0 }
                        }
                    }
                    "Spacebar" {
                        if ($currentStep -eq 0) {
                            if ($currentRoleIndex -eq $backIndex) {
                                return $null
                            }
                            $selected[$currentRoleIndex] = -not $selected[$currentRoleIndex]
                        }
                    }
                    "Enter" {
                        if ($currentStep -eq 0) {
                            # If on the Back item, go back
                            if ($currentRoleIndex -eq $backIndex) {
                                return $null
                            }
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
                        if ($currentStep -eq 0) {
                            return $null  # Back to action menu
                        } elseif ($currentStep -eq 1) {
                            $durationInput = ""
                            $currentStep = 0  # Back to role selection
                            [Console]::CursorVisible = $false
                        } elseif ($currentStep -eq 2) {
                            $justificationInput = ""
                            $currentStep = 1  # Back to duration
                        }
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
            [string]$DisplayProperty = $null,
            [switch]$ShowBack = $false,
            [switch]$ShowSubtitle = $false,
            [string]$HeaderStyle = "Entra"
        )
        
        if ($Items.Count -eq 0) {
            Write-Host "No items to select from." -ForegroundColor Red
            return @()
        }
        
        # Initialize selection state
        $selected = @{}
        $currentIndex = 0
        $totalDisplayItems = if ($ShowBack) { $Items.Count + 1 } else { $Items.Count }
        $backIndex = if ($ShowBack) { $Items.Count } else { -1 }

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
                switch ($HeaderStyle) {
                    "Groups" { Show-GroupsPIMHeader }
                    "Azure"  { Show-AzurePIMHeader }
                    default  { Show-PIMGlobalHeaderMinimal }
                }
                if ($ShowSubtitle) {
                    Write-Host "    with PowerShell" -ForegroundColor DarkGray
                }
                    Write-Host ""
                Write-Host $Title -ForegroundColor Cyan
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

                # Show Back item if enabled
                if ($ShowBack) {
                    $backArrow = if ($currentIndex -eq $backIndex) { "► " } else { "  " }
                    $backColor = if ($currentIndex -eq $backIndex) { "Yellow" } else { "Gray" }
                    Write-Host "$backArrow← Back" -ForegroundColor $backColor
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

                # Check for quit shortcut first (Ctrl+Q on both platforms)
                if (Test-QuitShortcut -Key $key) {
                    Invoke-PIMExit -Message "Exiting PIM role management..."
                }

                # Check for help shortcut (Ctrl+H on both platforms)
                if (Test-HelpShortcut -Key $key) {
                    Show-HelpMenu
                    continue
                }

                switch ($key.Key.ToString()) {
                    "UpArrow" {
                        $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $totalDisplayItems - 1 }
                    }
                    "DownArrow" {
                        $currentIndex = if ($currentIndex -lt ($totalDisplayItems - 1)) { $currentIndex + 1 } else { 0 }
                    }
                    "Spacebar" {
                        # If on the Back item, treat as back action
                        if ($ShowBack -and $currentIndex -eq $backIndex) {
                            return "BACK"
                        }
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
                        # If on the Back item, treat as back action
                        if ($ShowBack -and $currentIndex -eq $backIndex) {
                            return "BACK"
                        }
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
                        if ($ShowBack) { return "BACK" }
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

        do {
            [Console]::CursorVisible = $false
            Clear-Host
            Show-PIMGlobalHeaderMinimal

            # Create main choice menu items
            $menuItems = @(
                "Activate Roles",
                "Deactivate Roles"
            )

            # Show checkbox menu with single selection and back option
            $selectedIndices = Show-CheckboxMenu -Items $menuItems -Title "🔄 Choose Action" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -SingleSelection -ShowBack

            # Back returns to workflow selector
            if ($selectedIndices -eq "BACK") {
                return
            }

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
        } while ($true)
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
    
    
        [Console]::CursorVisible = $false
        if ($ActiveRoles.Count -eq 0) {
            Write-Host ""
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
                        Write-Host ""
                        Write-Host "Press Enter to exit..." -ForegroundColor Yellow
                        Read-Host
                    }
                }
            }
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
                $activationTime = [DateTime]::Parse($assignment.StartDateTime, [System.Globalization.CultureInfo]::InvariantCulture).ToLocalTime()
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
    
    # Build role expiration data for dynamic countdown menu
    # Use ExpirationTime already available on role objects from Get-ActiveRolesOptimized
    $roleExpirationData = @()
    foreach ($role in $readyToDeactivate) {
        $roleExpirationData += [PSCustomObject]@{
            Role = $role
            ExpirationTime = $role.ExpirationTime
        }
    }

    # Show dynamic countdown menu with live expiration timers and back option
    Clear-Host
    $selectedIndices = Show-DynamicExpirationMenu -RoleExpirationData $roleExpirationData -Title "🔄 Select Active Roles to Deactivate"

    if ($selectedIndices -eq "BACK") {
        return
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
        "Entra Group Roles",
        "Azure Resource Roles"
    )

    $selectedIndices = Show-CheckboxMenu -Items $menuItems -Title "🔄 Select Workflow" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -SingleSelection -ShowSubtitle

    if ($null -eq $selectedIndices -or $selectedIndices.Count -eq 0) {
        return 'Quit'
    }

    $selectedIndex = $selectedIndices[0]
    switch ($selectedIndex) {
        0 { return 'Entra' }
        1 { return 'Groups' }
        2 { return 'Azure' }
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
                principalId      = $script:AzureCurrentUserId  # Use current user's Object ID (handles group-based eligibility)
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
        return @{ Success = $true; Error = $null; ClaimsChallenge = $null }
    } catch {
        $errorMsg = $_.Exception.Message
        
        # Check for Conditional Access claims challenge (step-up authentication required)
        if ($errorMsg -like "*&claims=*") {
            $claimsMatch = [regex]::Match($errorMsg, '&claims=([^&\s\]]+)')
            if ($claimsMatch.Success) {
                $encodedClaims = $claimsMatch.Groups[1].Value
                $decodedClaims = [System.Web.HttpUtility]::UrlDecode($encodedClaims)
                return @{ Success = $false; Error = $errorMsg; ClaimsChallenge = $decodedClaims }
            }
        }
        
        # Provide friendlier message for common errors
        if ($errorMsg -match "already exists") {
            $errorMsg = "Already active (Azure API may take a few minutes to sync)"
        }
        return @{ Success = $false; Error = $errorMsg; ClaimsChallenge = $null }
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
                principalId      = $script:AzureCurrentUserId  # Use current user's Object ID (handles group-based eligibility)
                roleDefinitionId = $ActiveRole.RoleDefinitionId
                requestType      = "SelfDeactivate"
            }
        }

        $response = Invoke-AzurePIMApi -Path $path -Method "PUT" -Body $body
        return @{ Success = $true; Error = $null }
    } catch {
        $errorMsg = $_.Exception.Message
        # Provide friendlier message for common errors
        if ($errorMsg -match "does not exist|not found") {
            $errorMsg = "Role already deactivated"
        }
        return @{ Success = $false; Error = $errorMsg }
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
    Write-Host "[ A Z U R E   P I M ]" -ForegroundColor Magenta
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

        # Decode JWT to get account ID, tenant ID, and user Object ID
        $tokenParts = $accessToken.Split('.')
        $payload = $tokenParts[1]
        # Add padding if needed
        $padding = 4 - ($payload.Length % 4)
        if ($padding -ne 4) { $payload += '=' * $padding }
        $decodedPayload = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
        $claims = $decodedPayload | ConvertFrom-Json
        $accountId = if ($claims.upn) { $claims.upn } elseif ($claims.preferred_username) { $claims.preferred_username } else { $claims.sub }
        $tenantId = $claims.tid
        # Store user Object ID for use in PIM role activation (required for group-based eligible assignments)
        $script:AzureCurrentUserId = $claims.oid

        # Connect to Azure using the MSAL token (without SkipValidation to avoid needing subscription)
        $null = Connect-AzAccount -AccessToken $accessToken -AccountId $accountId -Tenant $tenantId -ErrorAction Stop -WarningAction SilentlyContinue

        $context = Get-AzContext
        if (-not $context) {
            throw "Failed to establish Azure context"
        }

        Write-Host "✅ Successfully connected to Azure" -ForegroundColor Green
        Write-Host "✅ Account: $($context.Account.Id)" -ForegroundColor Green

        # First, try to get PIM eligible roles directly (works even without subscription access)
        Write-Host "🔄 Checking for PIM eligible roles..." -ForegroundColor Cyan -NoNewline

        # Use the original access token from MSAL (already has management.azure.com scope)
        $headers = @{ Authorization = "Bearer $accessToken" }

        # Get eligible role assignments across all scopes the user can see
        $pimEligibleRoles = @()
        $swEligible = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            # Query at root scope to find all eligible assignments
            $uri = "https://management.azure.com/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?api-version=2020-10-01&`$filter=asTarget()"
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -ErrorAction SilentlyContinue
            if ($response.value) {
                $pimEligibleRoles = $response.value
            }
        } catch {
            # If root scope fails, that's okay - we'll try subscriptions next
        }
        $swEligible.Stop()
        Write-Host " [E:$($swEligible.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray
        
        if ($pimEligibleRoles.Count -gt 0) {
            Write-Host "✅ Found $($pimEligibleRoles.Count) PIM eligible role(s)" -ForegroundColor Green
            
            # Extract unique subscriptions from PIM roles
            $pimSubscriptionIds = $pimEligibleRoles | ForEach-Object {
                if ($_.properties.scope -match '/subscriptions/([^/]+)') {
                    $matches[1]
                }
            } | Where-Object { $_ } | Select-Object -Unique
            
            # Create subscription objects for selection
            $subscriptions = @()
            foreach ($subId in $pimSubscriptionIds) {
                $subName = $pimEligibleRoles | Where-Object { $_.properties.scope -match $subId } | 
                    Select-Object -First 1 -ExpandProperty properties | 
                    Select-Object -ExpandProperty expandedProperties | 
                    Select-Object -ExpandProperty scope | 
                    Select-Object -ExpandProperty displayName
                
                if (-not $subName) { $subName = $subId }
                
                $subscriptions += [PSCustomObject]@{
                    Name = $subName
                    Id = $subId
                }
            }

            # Build normalized role objects from root-scope data (reuse for Browse All Roles)
            $allNormalizedRoles = @()
            foreach ($role in $pimEligibleRoles) {
                $subId = $null
                $subName = "Unknown"
                if ($role.properties.scope -match '/subscriptions/([^/]+)') {
                    $subId = $matches[1]
                }
                $matchingSub = $subscriptions | Where-Object { $_.Id -eq $subId } | Select-Object -First 1
                if ($matchingSub) { $subName = $matchingSub.Name }

                $allNormalizedRoles += [PSCustomObject]@{
                    Id               = $role.id
                    Name             = $role.name
                    RoleDefinitionId = $role.properties.roleDefinitionId
                    RoleDisplayName  = $role.properties.expandedProperties.roleDefinition.displayName
                    Scope            = $role.properties.scope
                    ScopeDisplayName = $role.properties.expandedProperties.scope.displayName
                    ScopeType        = $role.properties.expandedProperties.scope.type
                    PrincipalId      = $role.properties.principalId
                    SubscriptionId   = $subId
                    SubscriptionName = $subName
                }
            }
        } else {
            # Fallback: Get subscriptions - include tenant ID to ensure we get all
            $subscriptions = @(Get-AzSubscription -TenantId $tenantId -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)

            # If still no subscriptions, try without tenant filter
            if ($subscriptions.Count -eq 0) {
                $subscriptions = @(Get-AzSubscription -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)
            }
        }
        
        if ($subscriptions.Count -eq 0) {
            Write-Host "❌ No subscriptions or PIM eligible roles found" -ForegroundColor Red
            Write-Host "   Make sure you have Reader access or PIM eligible roles" -ForegroundColor Gray
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

    } catch {
        Write-Host "❌ Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        [Console]::ReadKey($true) | Out-Null
        return
    }

    # User Object ID should already be set during token decode at connection time
    # Fallback to context Account.Id if not set (may be UPN instead of Object ID)
    if ([string]::IsNullOrEmpty($script:AzureCurrentUserId)) {
        $script:AzureCurrentUserId = (Get-AzContext).Account.Id
    }

    # Show view-mode menu when we have normalized role data from root-scope API
    if ($allNormalizedRoles.Count -gt 0) {
        do {
            $viewModeItems = @(
                "Browse All Roles",
                "Filter by Subscription"
            )

            $viewModeSelection = Show-AzureCheckboxMenu -Items $viewModeItems -Title "📦 How would you like to find roles?" -Prompt "Use arrow keys to navigate, SPACE to select, ENTER to confirm:" -SingleSelection -ShowBack

            if ($viewModeSelection -eq "BACK") {
                return
            }

            if ($null -eq $viewModeSelection -or $viewModeSelection.Count -eq 0) {
                return
            }

            $viewMode = $viewModeSelection[0]

            if ($viewMode -eq 0) {
                # Browse All Roles path
                Show-AzureBrowseAllRolesUI -AllRoles $allNormalizedRoles -Subscriptions $subscriptions
                # When Browse All returns (via BACK), loop back to view-mode menu
            } else {
                # Filter by Subscription path
                if ($subscriptions.Count -eq 1) {
                    # Auto-select the only subscription
                    $selectedSub = $subscriptions[0]
                    $script:AzureSelectedSubscriptions = @([PSCustomObject]@{
                        Id   = $selectedSub.Id
                        Name = $selectedSub.Name
                    })
                    Set-AzContext -SubscriptionId $selectedSub.Id -ErrorAction SilentlyContinue | Out-Null
                    Start-AzurePIMRoleManagement
                    # When role management returns (via BACK), loop back to view-mode menu
                } else {
                    do {
                        $selectedSubIndices = Show-AzureCheckboxMenu -Items ($subItems | ForEach-Object { $_.Name }) -Title "📦 Select Subscription" -Prompt "Use arrow keys to navigate, SPACE to select, ENTER to confirm:" -SingleSelection -ShowBack

                        if ($selectedSubIndices -eq "BACK") {
                            break  # Back to view-mode menu
                        }

                        if ($null -eq $selectedSubIndices -or $selectedSubIndices.Count -eq 0) {
                            break
                        }

                        $selectedSub = $subscriptions[$selectedSubIndices[0]]
                        $script:AzureSelectedSubscriptions = @([PSCustomObject]@{
                            Id   = $selectedSub.Id
                            Name = $selectedSub.Name
                        })

                        Set-AzContext -SubscriptionId $selectedSub.Id -ErrorAction SilentlyContinue | Out-Null

                        Start-AzurePIMRoleManagement
                    } while ($true)
                }
            }
        } while ($true)
    } else {
        # Fallback path (no PIM role data from root scope) - go directly to subscription selection
        do {
            $selectedSubIndices = Show-AzureCheckboxMenu -Items ($subItems | ForEach-Object { $_.Name }) -Title "📦 Select Subscription" -Prompt "Use arrow keys to navigate, SPACE to select, ENTER to confirm:" -SingleSelection -ShowBack

            if ($selectedSubIndices -eq "BACK") {
                return
            }

            if ($null -eq $selectedSubIndices -or $selectedSubIndices.Count -eq 0) {
                return
            }

            $selectedSub = $subscriptions[$selectedSubIndices[0]]
            $script:AzureSelectedSubscriptions = @([PSCustomObject]@{
                Id   = $selectedSub.Id
                Name = $selectedSub.Name
            })

            Set-AzContext -SubscriptionId $selectedSub.Id -ErrorAction SilentlyContinue | Out-Null

            Start-AzurePIMRoleManagement
        } while ($true)
    }
}

function Show-AzurePIMHeader {
    Write-Host "[ A Z U R E   P I M ]" -ForegroundColor Magenta
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

    Write-Host ""
    exit 0
}

function Show-AzureCheckboxMenu {
    param(
        [array]$Items,
        [string]$Title = "Select Items",
        [string]$Prompt = "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:",
        [switch]$SingleSelection = $false,
        [switch]$ShowBack = $false
    )

    if ($Items.Count -eq 0) {
        Write-Host "No items to select from." -ForegroundColor Red
        return @()
    }

    $selected = @{}
    $currentIndex = 0
    $totalDisplayItems = if ($ShowBack) { $Items.Count + 1 } else { $Items.Count }
    $backIndex = if ($ShowBack) { $Items.Count } else { -1 }

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

            # Show Back item if enabled
            if ($ShowBack) {
                $backArrow = if ($currentIndex -eq $backIndex) { "► " } else { "  " }
                $backColor = if ($currentIndex -eq $backIndex) { "Yellow" } else { "Gray" }
                Write-Host "$backArrow← Back" -ForegroundColor $backColor
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
                    $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $totalDisplayItems - 1 }
                }
                "DownArrow" {
                    $currentIndex = if ($currentIndex -lt ($totalDisplayItems - 1)) { $currentIndex + 1 } else { 0 }
                }
                "Spacebar" {
                    # If on the Back item, treat as back action
                    if ($ShowBack -and $currentIndex -eq $backIndex) {
                        [Console]::CursorVisible = $true
                        return "BACK"
                    }
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
                    # If on the Back item, treat as back action
                    if ($ShowBack -and $currentIndex -eq $backIndex) {
                        [Console]::CursorVisible = $true
                        return "BACK"
                    }
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
                    if ($ShowBack) { return "BACK" }
                    return @()
                }
            }

        } while ($true)
    } finally {
        [Console]::CursorVisible = $true
    }
}

function Show-AzureGroupedCheckboxMenu {
    param(
        [Parameter(Mandatory)]
        [array]$GroupedItems,
        [string]$Title = "Select Items",
        [string]$Prompt = "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:",
        [switch]$ShowBack = $false
    )

    if ($GroupedItems.Count -eq 0) {
        Write-Host "No items to select from." -ForegroundColor Red
        return @()
    }

    # Build list of selectable indices (skip headers)
    $selectableIndices = @()
    for ($i = 0; $i -lt $GroupedItems.Count; $i++) {
        if ($GroupedItems[$i].Type -eq 'Role') {
            $selectableIndices += $i
        }
    }

    if ($selectableIndices.Count -eq 0) {
        Write-Host "No selectable items." -ForegroundColor Red
        return @()
    }

    # Track selection state by role Index property
    $selected = @{}
    foreach ($idx in $selectableIndices) {
        $selected[$GroupedItems[$idx].Index] = $false
    }

    # Add back item position
    $backPosition = $GroupedItems.Count
    $allPositions = $selectableIndices + @($backPosition)

    # Current position in allPositions array
    $currentPosIdx = 0
    $currentIndex = $allPositions[$currentPosIdx]

    [Console]::CursorVisible = $false

    try {
        do {
            Clear-Host
            Show-AzurePIMHeader
            Write-Host ""
            Write-Host $Title -ForegroundColor Cyan
            Write-Host ""

            for ($i = 0; $i -lt $GroupedItems.Count; $i++) {
                $item = $GroupedItems[$i]
                if ($item.Type -eq 'Header') {
                    Write-Host ""
                    Write-Host "  📦 $($item.Text)" -ForegroundColor DarkCyan
                    $headerLen = $item.Text.Length + 4
                    Write-Host "  $('─' * $headerLen)" -ForegroundColor DarkGray
                } else {
                    $roleIdx = $item.Index
                    $checkbox = if ($selected[$roleIdx]) { "[✓]" } else { "[ ]" }
                    $arrow = if ($i -eq $currentIndex) { "► " } else { "  " }
                    $line = "$arrow$checkbox $($item.Text)"

                    if ($selected[$roleIdx]) {
                        Write-Host $line -ForegroundColor Green
                    } elseif ($i -eq $currentIndex) {
                        Write-Host $line -ForegroundColor Yellow
                    } else {
                        Write-Host $line -ForegroundColor White
                    }
                }
            }

            # Show Back item
            if ($ShowBack) {
                Write-Host ""
                $backArrow = if ($currentIndex -eq $backPosition) { "► " } else { "  " }
                $backColor = if ($currentIndex -eq $backPosition) { "Yellow" } else { "Gray" }
                Write-Host "$backArrow← Back" -ForegroundColor $backColor
            }

            Write-Host ""
            $selectedCount = ($selected.GetEnumerator() | Where-Object { $_.Value }).Count
            Write-Host "Roles Selected: $selectedCount" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "↑/↓ Navigate | SPACE Toggle | Ctrl+A Select All | ENTER Confirm | $(Get-HelpShortcutText) | $(Get-QuitShortcutText)" -ForegroundColor Magenta

            $key = [Console]::ReadKey($true)

            if (Test-QuitShortcut -Key $key) {
                Invoke-AzurePIMExit
            }

            # Ctrl+A to select/deselect all
            if ($key.Modifiers -band [ConsoleModifiers]::Control -and $key.Key -eq 'A') {
                $allSelected = ($selected.Values | Where-Object { $_ }).Count -eq $selectableIndices.Count
                foreach ($idx in $selectableIndices) {
                    $selected[$GroupedItems[$idx].Index] = -not $allSelected
                }
                continue
            }

            if (Test-HelpShortcut -Key $key) {
                Show-HelpMenu
                continue
            }

            switch ($key.Key) {
                "UpArrow" {
                    $currentPosIdx = if ($currentPosIdx -gt 0) { $currentPosIdx - 1 } else { $allPositions.Count - 1 }
                    $currentIndex = $allPositions[$currentPosIdx]
                }
                "DownArrow" {
                    $currentPosIdx = if ($currentPosIdx -lt ($allPositions.Count - 1)) { $currentPosIdx + 1 } else { 0 }
                    $currentIndex = $allPositions[$currentPosIdx]
                }
                "Spacebar" {
                    if ($ShowBack -and $currentIndex -eq $backPosition) {
                        [Console]::CursorVisible = $true
                        return "BACK"
                    }
                    if ($currentIndex -lt $GroupedItems.Count) {
                        $roleIdx = $GroupedItems[$currentIndex].Index
                        $selected[$roleIdx] = -not $selected[$roleIdx]
                    }
                }
                "Enter" {
                    if ($ShowBack -and $currentIndex -eq $backPosition) {
                        [Console]::CursorVisible = $true
                        return "BACK"
                    }
                    $selectedItems = @()
                    foreach ($entry in $selected.GetEnumerator()) {
                        if ($entry.Value) {
                            $selectedItems += $entry.Key
                        }
                    }
                    [Console]::CursorVisible = $true
                    return $selectedItems
                }
                "Escape" {
                    [Console]::CursorVisible = $true
                    if ($ShowBack) { return "BACK" }
                    return @()
                }
            }

        } while ($true)
    } finally {
        [Console]::CursorVisible = $true
    }
}

function Show-AzureBrowseAllRolesUI {
    param(
        [array]$AllRoles,
        [array]$Subscriptions
    )

    do {
        # Set AzureSelectedSubscriptions to ALL subscriptions for API queries
        $script:AzureSelectedSubscriptions = $Subscriptions | ForEach-Object {
            [PSCustomObject]@{ Id = $_.Id; Name = $_.Name }
        }

        # Show Activate/Deactivate action menu
        $menuItems = @(
            "Activate Roles",
            "Deactivate Roles"
        )

        $selectedIndices = Show-AzureCheckboxMenu -Items $menuItems -Title "🔄 Choose Action" -Prompt "Use arrow keys to navigate, SPACE to select, ENTER to confirm:" -SingleSelection -ShowBack

        if ($selectedIndices -eq "BACK") { return }
        if ($null -eq $selectedIndices -or $selectedIndices.Count -eq 0) { return }

        $selectedAction = $menuItems[$selectedIndices[0]]

        if ($selectedAction -eq "Activate Roles") {
            Clear-Host
            Show-AzurePIMHeader
            Write-Host ""
            Write-Host "🔄 Loading roles across all subscriptions..." -ForegroundColor Cyan -NoNewline

            # Get active roles across ALL subscriptions to filter them out
            $swActive = [System.Diagnostics.Stopwatch]::StartNew()
            $activeRoles = Get-AzureActiveRoles
            $swActive.Stop()
            Write-Host " [A:$($swActive.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline

            # Filter out already active roles
            $activeKeys = $activeRoles | ForEach-Object { "$($_.RoleDefinitionId)|$($_.Scope)" }
            $availableRoles = @($AllRoles | Where-Object {
                $key = "$($_.RoleDefinitionId)|$($_.Scope)"
                $activeKeys -notcontains $key
            })

            if ($availableRoles.Count -gt 0) {
                Write-Host " ✅ $($availableRoles.Count) available" -ForegroundColor Green
                Start-Sleep -Milliseconds 800
            } else {
                Write-Host ""
            }

            if ($availableRoles.Count -eq 0) {
                Write-Host ""
                Write-Host "❌ No eligible roles available for activation." -ForegroundColor Red
                Write-Host ""

                if ($activeRoles.Count -gt 0) {
                    Write-Host "Would you like to deactivate roles instead? (Y/N): " -NoNewline -ForegroundColor Cyan
                    [Console]::CursorVisible = $true

                    $promptLeft = [Console]::CursorLeft
                    $promptTop = [Console]::CursorTop

                    Write-Host "`n"
                    Write-Host "Y/N to choose | $(Get-QuitShortcutText)" -ForegroundColor Magenta
                    [Console]::SetCursorPosition($promptLeft, $promptTop)

                    $userInput = ""
                    do {
                        $key = [Console]::ReadKey($true)
                        if (Test-QuitShortcut -Key $key) { Invoke-AzurePIMExit; return }
                        if ($key.Key -eq 'Enter') {
                            if ($userInput -eq 'Y') {
                                Start-AzureRoleDeactivationWorkflow -ActiveRoles $activeRoles
                                break
                            } elseif ($userInput -eq 'N') {
                                break
                            } else {
                                Write-Host ""
                                Write-Host "Please enter Y or N: " -NoNewline -ForegroundColor Yellow
                                $userInput = ""
                            }
                        } elseif ($key.Key -eq 'Backspace' -and $userInput.Length -gt 0) {
                            $userInput = $userInput.Substring(0, $userInput.Length - 1)
                            Write-Host "`b `b" -NoNewline
                        } elseif ($key.KeyChar -match '[YyNn]' -and $userInput.Length -eq 0) {
                            $userInput = $key.KeyChar.ToString().ToUpper()
                            Write-Host $userInput -NoNewline -ForegroundColor Green
                        }
                    } while ($true)
                } else {
                    Write-Host "Check back later when roles are approved." -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "Press any key to continue..." -ForegroundColor Yellow
                    [Console]::ReadKey($true) | Out-Null
                }
                continue
            }

            # Build flat role list for display
            $roleItems = @()
            $sortedRoles = $availableRoles | Sort-Object RoleDisplayName, SubscriptionName

            foreach ($role in $sortedRoles) {
                $friendlyScope = $role.ScopeDisplayName
                if ($role.Scope -match '/resourceGroups/([^/]+)') {
                    $friendlyScope = "RG: $($matches[1])"
                } elseif ($role.ScopeType -eq 'Subscription' -or $role.Scope -match '/subscriptions/[^/]+$') {
                    $friendlyScope = "Subscription"
                }
                $roleItems += "$($role.RoleDisplayName) > $($role.SubscriptionName) > $friendlyScope"
            }

            # Show flat role selection
            $selectedRoleIndices = Show-AzureCheckboxMenu -Items $roleItems -Title "Select Roles to Activate" -ShowBack

            if ($selectedRoleIndices -eq "BACK") { continue }
            if ($null -eq $selectedRoleIndices -or $selectedRoleIndices.Count -eq 0) { continue }

            # Map indices to actual role objects
            $rolesToActivate = @()
            foreach ($idx in $selectedRoleIndices) {
                $rolesToActivate += $sortedRoles[$idx]
            }

            # Run the activation wizard
            Show-AzureActivationWizard -RolesToActivate $rolesToActivate

        } elseif ($selectedAction -eq "Deactivate Roles") {
            Clear-Host
            Show-AzurePIMHeader
            Write-Host ""
            Write-Host "🔄 Loading active roles across all subscriptions..." -ForegroundColor Cyan -NoNewline

            $swActive = [System.Diagnostics.Stopwatch]::StartNew()
            $activeRoles = Get-AzureActiveRoles
            $swActive.Stop()

            if ($activeRoles.Count -gt 0) {
                Write-Host " [A:$($swActive.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline
                Write-Host " ✅ $($activeRoles.Count) found" -ForegroundColor Green
            } else {
                Write-Host " [A:$($swActive.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray
            }

            Start-AzureRoleDeactivationWorkflow -ActiveRoles $activeRoles
        }
    } while ($true)
}

function Start-AzurePIMRoleManagement {
    do {
        [Console]::CursorVisible = $false

        # Always show both options - same as Entra workflow
        $menuItems = @(
            "Activate Roles",
            "Deactivate Roles"
        )

        # Show action menu using Azure checkbox menu with back option
        $selectedIndices = Show-AzureCheckboxMenu -Items $menuItems -Title "🔄 Choose Action" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -SingleSelection -ShowBack

        # Back returns to workflow selector
        if ($selectedIndices -eq "BACK") {
            return
        }

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

            $swEligible = [System.Diagnostics.Stopwatch]::StartNew()
            $eligibleRoles = Get-AzureEligibleRoles
            $swEligible.Stop()
            Write-Host " [E:$($swEligible.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline

            $swActive = [System.Diagnostics.Stopwatch]::StartNew()
            $activeRoles = Get-AzureActiveRoles
            $swActive.Stop()
            Write-Host " [A:$($swActive.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline

            # Filter out already active roles from eligible
            $activeKeys = $activeRoles | ForEach-Object { "$($_.RoleDefinitionId)|$($_.Scope)" }
            $availableForActivation = @($eligibleRoles | Where-Object {
                $key = "$($_.RoleDefinitionId)|$($_.Scope)"
                $activeKeys -notcontains $key
            })

            if ($availableForActivation.Count -gt 0) {
                Write-Host " ✅ $($availableForActivation.Count) found" -ForegroundColor Green
                Start-Sleep -Milliseconds 800
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

            $swActive = [System.Diagnostics.Stopwatch]::StartNew()
            $activeRoles = Get-AzureActiveRoles
            $swActive.Stop()

            if ($activeRoles.Count -gt 0) {
                Write-Host " [A:$($swActive.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline
                Write-Host " ✅ $($activeRoles.Count) found" -ForegroundColor Green
            } else {
                Write-Host " [A:$($swActive.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray
            }

            Start-AzureRoleDeactivationWorkflow -ActiveRoles $activeRoles
        }
    } while ($true)
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
        $roleItems += "$($role.RoleDisplayName) > $friendlyScope"
    }

    # Show role selection using Azure checkbox menu with back option
    $selectedIndices = Show-AzureCheckboxMenu -Items $roleItems -Title "Select Roles to Activate" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -ShowBack

    if ($selectedIndices -eq "BACK") {
        return
    }

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
        Write-Host "  ← Back" -ForegroundColor Gray
        Write-Host ""
        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

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
                } else {
                    # Any other key = go back
                    return "BACK"
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

function Show-AzureDynamicExpirationMenu {
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
            Show-AzurePIMHeader
            Write-Host ""
            Write-Host $Title -ForegroundColor Cyan
            Write-Host ""

            # Filter out expired roles and check if any remain
            $activeRoleData = @()
            $activeSelected = @()

            for ($i = 0; $i -lt $RoleExpirationData.Count; $i++) {
                $roleData = $RoleExpirationData[$i]
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
                        DisplayName = $roleData.DisplayName
                        ExpirationTime = $expirationTime
                        CountdownText = $countdownText
                        OriginalIndex = $i
                    }
                    $activeSelected += $selected[$i]
                }
            }

            # Check if all roles expired
            if ($activeRoleData.Count -eq 0) {
                Write-Host "ℹ️  All roles have expired." -ForegroundColor Gray
                Write-Host ""
                Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta
                do {
                    $key = [Console]::ReadKey($true)
                    if (Test-QuitShortcut -Key $key) { Invoke-AzurePIMExit }
                } while ($true)
            }

            # Update arrays to only include active roles
            $selected = $activeSelected

            # Calculate total display items (roles + back item)
            $backIndex = $activeRoleData.Count
            $totalDisplayItems = $activeRoleData.Count + 1

            if ($currentIndex -ge $totalDisplayItems) {
                $currentIndex = $totalDisplayItems - 1
            }

            # Display active roles with dynamic countdown
            for ($i = 0; $i -lt $activeRoleData.Count; $i++) {
                $roleInfo = $activeRoleData[$i]

                $checkbox = if ($selected[$i]) { "[✓]" } else { "[ ]" }
                $arrow = if ($i -eq $currentIndex) { "► " } else { "  " }

                Write-Host "$arrow$checkbox $($roleInfo.DisplayName) ($($roleInfo.CountdownText))" -ForegroundColor $(if ($i -eq $currentIndex) { "Yellow" } else { "White" })
            }

            # Show Back item
            $backArrow = if ($currentIndex -eq $backIndex) { "► " } else { "  " }
            $backColor = if ($currentIndex -eq $backIndex) { "Yellow" } else { "Gray" }
            Write-Host "$backArrow← Back" -ForegroundColor $backColor

            Write-Host ""
            $selectedCount = ($selected | Where-Object { $_ }).Count
            Write-Host "Roles Selected: $selectedCount" -ForegroundColor Green
            Write-Host ""
            Write-Host "↑/↓ Navigate | SPACE Toggle | Ctrl+A Select All | ENTER Confirm | $(Get-HelpShortcutText) | $(Get-QuitShortcutText)" -ForegroundColor Magenta

            # Handle input with timeout for countdown updates
            $inputAvailable = $false
            $timeout = 1000
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
                        if ($currentIndex -gt 0) { $currentIndex-- } else { $currentIndex = $totalDisplayItems - 1 }
                    }
                    "DownArrow" {
                        if ($currentIndex -lt ($totalDisplayItems - 1)) { $currentIndex++ } else { $currentIndex = 0 }
                    }
                    "Spacebar" {
                        if ($currentIndex -eq $backIndex) {
                            return "BACK"
                        }
                        $selected[$currentIndex] = -not $selected[$currentIndex]
                    }
                    "Enter" {
                        if ($currentIndex -eq $backIndex) {
                            return "BACK"
                        }
                        $selectedIndices = @()
                        for ($i = 0; $i -lt $selected.Count; $i++) {
                            if ($selected[$i]) {
                                $selectedIndices += $i
                            }
                        }
                        Clear-Host
                        return $selectedIndices
                    }
                    "Escape" {
                        return "BACK"
                    }
                }

                # Handle Ctrl+A to select/deselect all
                if ($key.Modifiers -eq "Control" -and $key.Key -eq "A") {
                    $allSelected = ($selected | Where-Object { $_ -eq $true }).Count -eq $selected.Count
                    for ($i = 0; $i -lt $selected.Count; $i++) {
                        $selected[$i] = -not $allSelected
                    }
                }

                # Handle Ctrl+H for help menu
                if ($key.Modifiers -eq "Control" -and $key.Key -eq "H") {
                    Show-HelpMenu
                }

                # Handle Ctrl+Q
                if (Test-QuitShortcut -Key $key) {
                    Invoke-AzurePIMExit
                }
            }

        } while ($true)
    }
    finally {
        # Keep cursor hidden - calling code manages visibility
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
                $activationTime = [DateTime]::Parse($role.StartDateTime, [System.Globalization.CultureInfo]::InvariantCulture).ToLocalTime()
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

    # Build role expiration data for dynamic countdown menu
    $roleExpirationData = @()
    foreach ($role in $readyToDeactivate) {
        $friendlyScope = $role.ScopeDisplayName
        if ($role.ScopeDisplayName -match '/subscriptions/[^/]+/resourceGroups/([^/]+)') {
            $friendlyScope = $Matches[1]
        } elseif ($role.ScopeDisplayName -match '/subscriptions/[^/]+$') {
            $friendlyScope = "Subscription"
        }

        $expirationTime = $null
        if ($role.EndDateTime) {
            $expirationTime = [DateTime]::Parse($role.EndDateTime, [System.Globalization.CultureInfo]::InvariantCulture).ToLocalTime()
        }

        $roleExpirationData += [PSCustomObject]@{
            DisplayName = "$($role.RoleDisplayName) > $friendlyScope"
            ExpirationTime = $expirationTime
        }
    }

    # Show dynamic countdown menu with live expiration timers and back option
    $selectedIndices = Show-AzureDynamicExpirationMenu -RoleExpirationData $roleExpirationData -Title "🔄 Select Roles to Deactivate"

    if ($selectedIndices -eq "BACK") {
        return
    }

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
        $roleName = $role.RoleDisplayName
        $result = Stop-AzureRoleActivation -ActiveRole $role
        if ($result.Success) {
            Write-Host "✅ Successfully deactivated: $roleName" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "❌ Failed to deactivate: $roleName - $($result.Error)" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host ""
    if ($successCount -gt 0 -and $failCount -eq 0) {
        # No summary needed - individual messages are sufficient
    } elseif ($successCount -gt 0 -and $failCount -gt 0) {
        Write-Host "⚠️ Deactivated $successCount role(s), $failCount failed" -ForegroundColor Yellow
    } elseif ($failCount -gt 0 -and $successCount -eq 0) {
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
        $result = Start-AzureRoleActivation -EligibleRole $role -Justification $justification -Duration $duration
        if ($result.Success) {
            Write-Host "✅ Role activation submitted for: $roleName" -ForegroundColor Green
            $successCount++
        } elseif ($result.ClaimsChallenge) {
            # Conditional Access requires step-up authentication (ACRS claim)
            Write-Host "🔐 $roleName requires additional authentication (Conditional Access)..." -ForegroundColor Yellow
            
            try {
                # Get new token with claims challenge
                $newToken = Get-AzureBrowserAccessTokenWithClaims -Claims $result.ClaimsChallenge
                
                if ($newToken) {
                    # Decode JWT to get account ID, tenant ID
                    $tokenParts = $newToken.Split('.')
                    $payload = $tokenParts[1]
                    # Add padding if needed
                    $padding = 4 - ($payload.Length % 4)
                    if ($padding -ne 4) { $payload += '=' * $padding }
                    $decodedPayload = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
                    $claims = $decodedPayload | ConvertFrom-Json
                    $accountId = if ($claims.upn) { $claims.upn } elseif ($claims.preferred_username) { $claims.preferred_username } else { $claims.sub }
                    $tenantId = $claims.tid
                    
                    # Reconnect to Azure with new token
                    Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
                    Clear-AzContext -Force -ErrorAction SilentlyContinue | Out-Null
                    $null = Connect-AzAccount -AccessToken $newToken -AccountId $accountId -Tenant $tenantId -ErrorAction Stop -WarningAction SilentlyContinue
                    
                    # Retry the activation request
                    $retryResult = Start-AzureRoleActivation -EligibleRole $role -Justification $justification -Duration $duration
                    if ($retryResult.Success) {
                        Write-Host "✅ Role activation submitted for: $roleName" -ForegroundColor Green
                        $successCount++
                    } else {
                        Write-Host "❌ Failed to activate: $roleName - $($retryResult.Error)" -ForegroundColor Red
                        $failCount++
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
            Write-Host "❌ Failed to activate: $roleName - $($result.Error)" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host ""
    if ($successCount -gt 0 -and $failCount -gt 0) {
        Write-Host "⚠️ Activated $successCount role(s), $failCount failed" -ForegroundColor Yellow
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

# ========================= Groups PIM Functions =========================

function Show-GroupsPIMHeader {
    Write-Host "[ P I M   G R O U P S ]" -ForegroundColor Magenta
}

function Invoke-GroupsPIMExit {
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

    Write-Host ""
    exit 0
}

function Get-EligibleGroupsOptimized {
    param([string]$CurrentUserId)

    $allEligibleGroups = @()
    $activeGroupKeys = @()

    try {
        $swTotal = [System.Diagnostics.Stopwatch]::StartNew()

        # Fetch eligible group assignments
        $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
        $eligibleUri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/eligibilitySchedules?`$filter=principalId eq '$CurrentUserId'&`$expand=group"
        $eligibleResponse = Invoke-MgGraphRequest -Method GET -Uri $eligibleUri -ErrorAction Stop
        $eligibleSchedules = if ($eligibleResponse -and $eligibleResponse.value) { $eligibleResponse.value } else { @() }
        $sw1.Stop()
        Write-Host " [E:$($sw1.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline

        # Fetch active group assignments to filter them out
        $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $activeUri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/assignmentScheduleInstances?`$filter=principalId eq '$CurrentUserId'"
            $activeResponse = Invoke-MgGraphRequest -Method GET -Uri $activeUri -ErrorAction Stop
            $activeAssignments = if ($activeResponse -and $activeResponse.value) { $activeResponse.value } else { @() }
        } catch { $activeAssignments = @() }
        $sw2.Stop()
        Write-Host " [A:$($sw2.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline

        # Build active keys for filtering
        foreach ($active in $activeAssignments) {
            $activeGroupKeys += "$($active.groupId):$($active.accessId)"
        }

        # Build eligible group objects
        $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ($schedule in $eligibleSchedules) {
            $groupName = if ($schedule.group -and $schedule.group.displayName) { $schedule.group.displayName } else { $schedule.groupId }
            $allEligibleGroups += [PSCustomObject]@{
                GroupName   = $groupName
                GroupId     = $schedule.groupId
                AccessId    = $schedule.accessId
                PrincipalId = $schedule.principalId
            }
        }
        $sw3.Stop()
        Write-Host " [C:$($sw3.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray -NoNewline

        $swTotal.Stop()
        Write-Host " [T:$($swTotal.ElapsedMilliseconds)ms]" -ForegroundColor DarkGray
    } catch {
        Write-Host " Err: $($_.Exception.Message)" -ForegroundColor Red
        $allEligibleGroups = @()
    }

    # Filter out active groups
    $eligibleGroups = $allEligibleGroups | Where-Object {
        $key = "$($_.GroupId):$($_.AccessId)"
        $activeGroupKeys -notcontains $key
    }

    return $eligibleGroups
}

function Get-ActiveGroupsOptimized {
    param([string]$CurrentUserId)

    $activeGroups = @()
    try {
        $uri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/assignmentScheduleInstances?`$filter=principalId eq '$CurrentUserId' and assignmentType eq 'Activated'&`$expand=group"
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        $instances = if ($response -and $response.value) { $response.value } else { @() }

        foreach ($instance in $instances) {
            $groupName = if ($instance.group -and $instance.group.displayName) { $instance.group.displayName } else { $instance.groupId }

            $expirationTime = $null
            if ($instance.endDateTime) {
                $expirationTime = [DateTime]::Parse($instance.endDateTime, [System.Globalization.CultureInfo]::InvariantCulture).ToLocalTime()
            }

            $activeGroups += [PSCustomObject]@{
                GroupName = $groupName
                Assignment = [PSCustomObject]@{
                    Id          = $instance.id
                    GroupId     = $instance.groupId
                    AccessId    = $instance.accessId
                    PrincipalId = $instance.principalId
                    StartDateTime = $instance.startDateTime
                    EndDateTime = $instance.endDateTime
                }
                ExpirationTime = $expirationTime
            }
        }
    } catch {
        $activeGroups = @()
    }

    return $activeGroups
}

function Submit-GroupActivation {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$EligibleGroup,
        [Parameter(Mandatory)]
        [string]$Justification,
        [Parameter(Mandatory)]
        [string]$Duration
    )

    try {
        $body = @{
            accessId    = "member"
            principalId = $EligibleGroup.PrincipalId
            groupId     = $EligibleGroup.GroupId
            action      = "selfActivate"
            justification = $Justification
            scheduleInfo = @{
                startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                expiration = @{
                    type     = "afterDuration"
                    duration = $Duration
                }
            }
        }

        $uri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/assignmentScheduleRequests"
        $result = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType "application/json" -ErrorAction Stop

        return @{ Success = $true; Status = $result.status; Error = $null; ClaimsChallenge = $null }
    } catch {
        $errorMsg = $_.Exception.Message

        # Check for Conditional Access claims challenge (step-up authentication required)
        if ($errorMsg -like "*AcrsValidationFailed*" -or $errorMsg -like "*&claims=*") {
            $claimsMatch = [regex]::Match($errorMsg, '&claims=([^&\s\]]+)')
            if ($claimsMatch.Success) {
                $encodedClaims = $claimsMatch.Groups[1].Value
                $decodedClaims = [System.Web.HttpUtility]::UrlDecode($encodedClaims)
                return @{ Success = $false; Status = "ClaimsChallenge"; Error = $errorMsg; ClaimsChallenge = $decodedClaims }
            }
        }

        if ($errorMsg -match "already exists" -or $errorMsg -match "RoleAssignmentExists") {
            $errorMsg = "Already active"
        }
        return @{ Success = $false; Status = "Failed"; Error = $errorMsg; ClaimsChallenge = $null }
    }
}

function Submit-GroupDeactivation {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ActiveGroup
    )

    try {
        $body = @{
            accessId    = "member"
            principalId = $ActiveGroup.Assignment.PrincipalId
            groupId     = $ActiveGroup.Assignment.GroupId
            action      = "selfDeactivate"
        }

        $uri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/assignmentScheduleRequests"
        $result = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType "application/json" -ErrorAction Stop

        return @{ Success = $true; Error = $null }
    } catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -match "does not exist|not found") {
            $errorMsg = "Group membership already deactivated"
        }
        return @{ Success = $false; Error = $errorMsg }
    }
}

function Show-GroupsDeactivationCountdown {
    param([array]$TooNewGroups)

    try {
        [Console]::CursorVisible = $false

        Clear-Host
        Show-GroupsPIMHeader
        Write-Host ""
        Write-Host "⏰ Time Remaining Until Groups Can Be Deactivated" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   (5-minute minimum activation period required)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   The deactivation menu will automatically refresh when timers expire" -ForegroundColor Cyan
        Write-Host ""

        # Remember the starting line for groups
        $groupStartLine = [Console]::CursorTop

        # Deduplicate groups by name
        $uniqueGroups = @{}
        $deduplicatedGroups = @()
        foreach ($groupInfo in $TooNewGroups) {
            if (-not $uniqueGroups.ContainsKey($groupInfo.GroupName)) {
                $uniqueGroups[$groupInfo.GroupName] = $true
                $deduplicatedGroups += $groupInfo
            }
        }

        # Show initial group lines
        foreach ($groupInfo in $deduplicatedGroups) {
            Write-Host "  ⏳ $($groupInfo.GroupName): --:-- remaining" -ForegroundColor Cyan
        }
        Write-Host ""
        Write-Host "  ← Back" -ForegroundColor Gray
        Write-Host ""
        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

        do {
            $allReady = $true

            # Update each group's countdown in place
            for ($i = 0; $i -lt $deduplicatedGroups.Count; $i++) {
                $groupInfo = $deduplicatedGroups[$i]
                try {
                    $activationTime = $groupInfo.ActivationTime
                    $deactivationTime = $activationTime.AddMinutes(5)
                    $timeRemaining = $deactivationTime - (Get-Date)

                    # Position cursor at this group's line
                    $lineNumber = $groupStartLine + $i
                    [Console]::SetCursorPosition(0, $lineNumber)

                    if ($timeRemaining.TotalSeconds -gt 0) {
                        $allReady = $false
                        $minutes = [int][math]::Floor($timeRemaining.TotalMinutes)
                        $seconds = [int][math]::Floor($timeRemaining.TotalSeconds % 60)
                        $timeDisplay = "{0:D2}:{1:D2}" -f $minutes, $seconds

                        Write-Host "  ⏳ $($groupInfo.GroupName): $timeDisplay remaining" -ForegroundColor Cyan -NoNewline
                        Write-Host (" " * ([Console]::WindowWidth - [Console]::CursorLeft - 1))
                    } else {
                        Write-Host "  ✅ $($groupInfo.GroupName): Ready for deactivation!" -ForegroundColor Green -NoNewline
                        Write-Host (" " * ([Console]::WindowWidth - [Console]::CursorLeft - 1))
                    }
                } catch {
                    $lineNumber = $groupStartLine + $i
                    [Console]::SetCursorPosition(0, $lineNumber)
                    Write-Host (" " * ([Console]::WindowWidth - 1)) -NoNewline
                    [Console]::SetCursorPosition(0, $lineNumber)
                    Write-Host "  ❓ $($groupInfo.GroupName): Unable to check" -ForegroundColor Yellow
                }
            }

            # Check if user pressed a key
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if (Test-QuitShortcut -Key $key) {
                    Invoke-GroupsPIMExit
                } else {
                    # Any other key = go back
                    return "BACK"
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

function Show-GroupsDynamicExpirationMenu {
    param(
        [array]$GroupExpirationData,
        [string]$Title
    )

    [Console]::CursorVisible = $false
    $currentIndex = 0
    $selected = @()
    for ($i = 0; $i -lt $GroupExpirationData.Count; $i++) {
        $selected += $false
    }

    try {
        do {
            Clear-Host
            Show-GroupsPIMHeader
            Write-Host ""
            Write-Host $Title -ForegroundColor Cyan
            Write-Host ""

            # Filter out expired groups and check if any remain
            $activeGroupData = @()
            $activeSelected = @()

            for ($i = 0; $i -lt $GroupExpirationData.Count; $i++) {
                $groupData = $GroupExpirationData[$i]
                $expirationTime = $groupData.ExpirationTime

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

                # Only include non-expired groups
                if (-not $isExpired) {
                    $activeGroupData += @{
                        DisplayName    = $groupData.DisplayName
                        ExpirationTime = $expirationTime
                        CountdownText  = $countdownText
                        OriginalIndex  = $i
                    }
                    $activeSelected += $selected[$i]
                }
            }

            # Check if all groups expired
            if ($activeGroupData.Count -eq 0) {
                Write-Host "ℹ️  All group memberships have expired." -ForegroundColor Gray
                Write-Host ""
                Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta
                do {
                    $key = [Console]::ReadKey($true)
                    if (Test-QuitShortcut -Key $key) { Invoke-GroupsPIMExit }
                } while ($true)
            }

            # Update arrays to only include active groups
            $selected = $activeSelected

            # Calculate total display items (groups + back item)
            $backIndex = $activeGroupData.Count
            $totalDisplayItems = $activeGroupData.Count + 1

            if ($currentIndex -ge $totalDisplayItems) {
                $currentIndex = $totalDisplayItems - 1
            }

            # Display active groups with dynamic countdown
            for ($i = 0; $i -lt $activeGroupData.Count; $i++) {
                $groupInfo = $activeGroupData[$i]

                $checkbox = if ($selected[$i]) { "[✓]" } else { "[ ]" }
                $arrow = if ($i -eq $currentIndex) { "► " } else { "  " }

                Write-Host "$arrow$checkbox $($groupInfo.DisplayName) ($($groupInfo.CountdownText))" -ForegroundColor $(if ($i -eq $currentIndex) { "Yellow" } else { "White" })
            }

            # Show Back item
            $backArrow = if ($currentIndex -eq $backIndex) { "► " } else { "  " }
            $backColor = if ($currentIndex -eq $backIndex) { "Yellow" } else { "Gray" }
            Write-Host "$backArrow← Back" -ForegroundColor $backColor

            Write-Host ""
            $selectedCount = ($selected | Where-Object { $_ }).Count
            Write-Host "Groups Selected: $selectedCount" -ForegroundColor Green
            Write-Host ""
            Write-Host "↑/↓ Navigate | SPACE Toggle | Ctrl+A Select All | ENTER Confirm | $(Get-HelpShortcutText) | $(Get-QuitShortcutText)" -ForegroundColor Magenta

            # Handle input with timeout for countdown updates
            $inputAvailable = $false
            $timeout = 1000
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
                        if ($currentIndex -gt 0) { $currentIndex-- } else { $currentIndex = $totalDisplayItems - 1 }
                    }
                    "DownArrow" {
                        if ($currentIndex -lt ($totalDisplayItems - 1)) { $currentIndex++ } else { $currentIndex = 0 }
                    }
                    "Spacebar" {
                        if ($currentIndex -eq $backIndex) {
                            return "BACK"
                        }
                        $selected[$currentIndex] = -not $selected[$currentIndex]
                    }
                    "Enter" {
                        if ($currentIndex -eq $backIndex) {
                            return "BACK"
                        }
                        $selectedIndices = @()
                        for ($i = 0; $i -lt $selected.Count; $i++) {
                            if ($selected[$i]) {
                                $selectedIndices += $i
                            }
                        }
                        Clear-Host
                        return $selectedIndices
                    }
                    "Escape" {
                        return "BACK"
                    }
                }

                # Handle Ctrl+A to select/deselect all
                if ($key.Modifiers -eq "Control" -and $key.Key -eq "A") {
                    $allSelected = ($selected | Where-Object { $_ -eq $true }).Count -eq $selected.Count
                    for ($i = 0; $i -lt $selected.Count; $i++) {
                        $selected[$i] = -not $allSelected
                    }
                }

                # Handle Ctrl+H for help menu
                if ($key.Modifiers -eq "Control" -and $key.Key -eq "H") {
                    Show-HelpMenu
                }

                # Handle Ctrl+Q
                if (Test-QuitShortcut -Key $key) {
                    Invoke-GroupsPIMExit
                }
            }

        } while ($true)
    }
    finally {
        # Keep cursor hidden - calling code manages visibility
    }
}

function Start-GroupActivationWorkflow {
    param(
        [array]$EligibleGroups,
        [string]$CurrentUserId
    )

    if ($EligibleGroups.Count -eq 0) {
        Clear-Host
        Show-GroupsPIMHeader
        Write-Host ""
        Write-Host "❌ No eligible groups available for activation." -ForegroundColor Red
        Write-Host ""

        # Check if there are active groups to offer deactivation
        $activeGroups = Get-ActiveGroupsOptimized -CurrentUserId $CurrentUserId
        if ($activeGroups.Count -gt 0) {
            Write-Host "Would you like to deactivate groups instead? (Y/N): " -NoNewline -ForegroundColor Cyan

            [Console]::CursorVisible = $true

            $promptLeft = [Console]::CursorLeft
            $promptTop = [Console]::CursorTop

            Write-Host "`n"
            Write-Host "Y/N to choose | $(Get-QuitShortcutText)" -ForegroundColor Magenta

            [Console]::SetCursorPosition($promptLeft, $promptTop)

            $userInput = ""
            do {
                $key = [Console]::ReadKey($true)

                if (Test-QuitShortcut -Key $key) {
                    Invoke-GroupsPIMExit
                    return
                }

                if ($key.Key -eq 'Enter') {
                    if ($userInput -eq 'Y') {
                        Start-GroupDeactivationWorkflow -ActiveGroups $activeGroups -CurrentUserId $CurrentUserId
                        return
                    } elseif ($userInput -eq 'N') {
                        Clear-Host
                        Show-GroupsPIMHeader
                        Write-Host ""
                        Write-Host "❌ No group management workflows available." -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "Check back later when groups are approved or activated." -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

                        [Console]::CursorVisible = $false
                        do {
                            $k = [Console]::ReadKey($true)
                            if (Test-QuitShortcut -Key $k) {
                                Invoke-GroupsPIMExit
                            }
                        } while ($true)
                        return
                    } else {
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
                elseif ($key.Key -eq 'Backspace' -and $userInput.Length -gt 0) {
                    $userInput = $userInput.Substring(0, $userInput.Length - 1)
                    Write-Host "`b `b" -NoNewline
                }
                elseif ($key.KeyChar -match '[YyNn]' -and $userInput.Length -eq 0) {
                    $userInput = $key.KeyChar.ToString().ToUpper()
                    Write-Host $userInput -NoNewline -ForegroundColor Green
                }
            } while ($true)
        } else {
            Write-Host "❌ No group management workflows available." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Check back later when groups are approved or activated." -ForegroundColor Gray
            Write-Host ""
            Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

            do {
                $key = [Console]::ReadKey($true)
                if (Test-QuitShortcut -Key $key) {
                    Invoke-GroupsPIMExit
                }
            } while ($true)
        }
        return
    }

    # Build group items for display
    $groupItems = @()
    foreach ($group in $EligibleGroups) {
        $groupItems += $group.GroupName
    }

    # Show checkbox menu for group selection with back option
    $selectedIndices = Show-CheckboxMenu -Items $groupItems -Title "Select Groups to Activate" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -ShowBack -HeaderStyle "Groups"

    if ($selectedIndices -eq "BACK") {
        return
    }

    if ($null -eq $selectedIndices -or $selectedIndices.Count -eq 0) {
        return
    }

    # Get selected groups
    $groupsToActivate = @()
    foreach ($idx in $selectedIndices) {
        $groupsToActivate += $EligibleGroups[$idx]
    }

    # Clear and show header for activation wizard
    Clear-Host
    Show-GroupsPIMHeader
    Write-Host ""

    # Duration input - same as Entra/Azure workflow
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
        return
    }

    # Justification input
    $justification = Read-PIMInput -Prompt "Enter reason for activation" -ControlsText $script:ControlMessages['Input']

    if ([string]::IsNullOrWhiteSpace($justification)) {
        Write-Host "Justification is required." -ForegroundColor Red
        return
    }

    Write-Host "🔄 Activating $($groupsToActivate.Count) group(s)..." -ForegroundColor Cyan
    Write-Host ""

    $successCount = 0
    $failCount = 0

    foreach ($group in $groupsToActivate) {
        $groupName = $group.GroupName
        $result = Submit-GroupActivation -EligibleGroup $group -Justification $justification -Duration $duration

        if ($result.Success) {
            if ($result.Status -eq "PendingApproval") {
                Write-Host "⏳ Group activation submitted for: $groupName (pending approval)" -ForegroundColor Yellow
            } else {
                Write-Host "✅ Group activation submitted for: $groupName" -ForegroundColor Green
            }
            $successCount++
        } elseif ($result.ClaimsChallenge) {
            # Conditional Access requires step-up authentication (ACRS claim)
            Write-Host "🔐 $groupName requires additional authentication (Conditional Access)..." -ForegroundColor Yellow

            try {
                # Get new token with claims challenge using Graph scopes
                $scopes = @(
                    'PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup',
                    'PrivilegedAccess.ReadWrite.AzureADGroup',
                    'RoleManagementPolicy.Read.AzureADGroup'
                )
                $newToken = Get-BrowserAccessTokenWithClaims -Scopes $scopes -Claims $result.ClaimsChallenge

                if ($newToken) {
                    # Reconnect to Graph with new token
                    $secureToken = ConvertTo-SecureString $newToken -AsPlainText -Force
                    Connect-MgGraph -AccessToken $secureToken -NoWelcome -ErrorAction Stop

                    # Retry the activation request
                    $retryResult = Submit-GroupActivation -EligibleGroup $group -Justification $justification -Duration $duration
                    if ($retryResult.Success) {
                        if ($retryResult.Status -eq "PendingApproval") {
                            Write-Host "⏳ Group activation submitted for: $groupName (pending approval)" -ForegroundColor Yellow
                        } else {
                            Write-Host "✅ Group activation submitted for: $groupName" -ForegroundColor Green
                        }
                        $successCount++
                    } else {
                        Write-Host "❌ Failed to activate: $groupName - $($retryResult.Error)" -ForegroundColor Red
                        $failCount++
                    }
                } else {
                    Write-Host "❌ Failed to activate: $groupName - Step-up authentication failed" -ForegroundColor Red
                    $failCount++
                }
            } catch {
                Write-Host "❌ Failed to activate: $groupName - $($_.Exception.Message)" -ForegroundColor Red
                $failCount++
            }
        } else {
            Write-Host "❌ Failed to activate: $groupName - $($result.Error)" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host ""
    if ($successCount -gt 0 -and $failCount -gt 0) {
        Write-Host "⚠️ Activated $successCount group(s), $failCount failed" -ForegroundColor Yellow
    } elseif ($failCount -gt 0 -and $successCount -eq 0) {
        Write-Host "❌ Failed to activate $failCount group(s)" -ForegroundColor Red
    }

    Write-Host ""

    # Ask if user wants to manage more groups
    do {
        [Console]::CursorVisible = $true
        $userInput = Read-PIMInput -Prompt "Would you like to manage more groups? (Y/N)" -ControlsText $script:ControlMessages['Exit']
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
        return
    } else {
        Write-Host "❌ No group management workflows available." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Check back later when groups are approved or activated." -ForegroundColor Gray
        Write-Host ""
        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

        [Console]::CursorVisible = $false
        do {
            $key = [Console]::ReadKey($true)
            if (Test-QuitShortcut -Key $key) {
                Invoke-GroupsPIMExit
            }
        } while ($true)
    }
}

function Start-GroupDeactivationWorkflow {
    param(
        [array]$ActiveGroups,
        [string]$CurrentUserId
    )

    [Console]::CursorVisible = $false
    if ($ActiveGroups.Count -eq 0) {
        Write-Host ""
        Write-Host "ℹ️  No active groups to deactivate at this time." -ForegroundColor Gray
        Write-Host ""

        $response = Read-PIMInput -Prompt "Would you like to activate groups instead? (Y/N)" -ForegroundColor Cyan

        if ($response) {
            $userInput = $response.Trim().ToUpper()
            if ($userInput -eq "Y" -or $userInput -eq "YES") {
                Clear-Host
                Show-GroupsPIMHeader
                Write-Host ""
                Write-Host "🔄 Loading eligible groups..." -ForegroundColor Cyan -NoNewline
                $eligibleGroups = Get-EligibleGroupsOptimized -CurrentUserId $CurrentUserId
                if ($eligibleGroups.Count -gt 0) {
                    Write-Host " ✅ $($eligibleGroups.Count) found" -ForegroundColor Green
                    Start-GroupActivationWorkflow -EligibleGroups $eligibleGroups -CurrentUserId $CurrentUserId
                } else {
                    Write-Host ""
                    Write-Host ""
                    Write-Host "❌ No eligible groups available for activation." -ForegroundColor Red
                }
                return
            }
        }

        # User hit N or gave no response — no workflows available
        Write-Host ""
        Write-Host "❌ No group management workflows available." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Check back later when groups are approved or activated." -ForegroundColor Gray
        Write-Host ""
        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

        [Console]::CursorVisible = $false
        do {
            $key = [Console]::ReadKey($true)
            if (Test-QuitShortcut -Key $key) {
                Invoke-GroupsPIMExit
            }
        } while ($true)
        return
    }

    # Check for groups that are too new to deactivate (5-minute rule)
    $readyToDeactivate = @()
    $tooNewGroups = @()

    foreach ($group in $ActiveGroups) {
        try {
            $assignment = $group.Assignment
            if ($assignment.StartDateTime) {
                $activationTime = [DateTime]::Parse($assignment.StartDateTime, [System.Globalization.CultureInfo]::InvariantCulture).ToLocalTime()
                $timeSinceActivation = (Get-Date) - $activationTime

                if ($timeSinceActivation.TotalMinutes -lt 5) {
                    $tooNewGroups += [PSCustomObject]@{
                        GroupName      = $group.GroupName
                        ActivationTime = $activationTime
                        Group          = $group
                    }
                } else {
                    $readyToDeactivate += $group
                }
            } else {
                $readyToDeactivate += $group
            }
        } catch {
            $readyToDeactivate += $group
        }
    }

    # If some groups are too new, show countdown
    if ($tooNewGroups.Count -gt 0) {
        [Console]::CursorVisible = $false
        Clear-Host
        Show-GroupsPIMHeader
        Write-Host ""

        if ($readyToDeactivate.Count -eq 0) {
            Write-Host "⏰ All groups are within the 5-minute activation period." -ForegroundColor Yellow
        } else {
            Write-Host "⏰ Some groups are within the 5-minute activation period." -ForegroundColor Yellow
        }
        Write-Host "Showing countdown until they can be deactivated..." -ForegroundColor Cyan
        Write-Host ""

        $countdownResult = Show-GroupsDeactivationCountdown -TooNewGroups $tooNewGroups

        if ($countdownResult -eq $true) {
            Start-GroupDeactivationWorkflow -ActiveGroups $ActiveGroups -CurrentUserId $CurrentUserId
        }
        return
    }

    # Build group expiration data for dynamic countdown menu
    $groupExpirationData = @()
    foreach ($group in $readyToDeactivate) {
        $groupExpirationData += [PSCustomObject]@{
            DisplayName    = $group.GroupName
            ExpirationTime = $group.ExpirationTime
        }
    }

    # Show dynamic countdown menu with live expiration timers and back option
    $selectedIndices = Show-GroupsDynamicExpirationMenu -GroupExpirationData $groupExpirationData -Title "🔄 Select Groups to Deactivate"

    if ($selectedIndices -eq "BACK") {
        return
    }

    if ($null -eq $selectedIndices -or $selectedIndices.Count -eq 0) {
        return
    }

    # Get selected groups
    $groupsToDeactivate = @()
    foreach ($idx in $selectedIndices) {
        $groupsToDeactivate += $readyToDeactivate[$idx]
    }

    # Deactivate groups
    Clear-Host
    Show-GroupsPIMHeader
    Write-Host ""
    Write-Host "🔄 Deactivating $($groupsToDeactivate.Count) group(s)..." -ForegroundColor Cyan
    Write-Host ""

    $successCount = 0
    $failCount = 0

    foreach ($group in $groupsToDeactivate) {
        $groupName = $group.GroupName
        $result = Submit-GroupDeactivation -ActiveGroup $group
        if ($result.Success) {
            Write-Host "✅ Successfully deactivated: $groupName" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "❌ Failed to deactivate: $groupName - $($result.Error)" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host ""
    if ($successCount -gt 0 -and $failCount -gt 0) {
        Write-Host "⚠️ Deactivated $successCount group(s), $failCount failed" -ForegroundColor Yellow
    } elseif ($failCount -gt 0 -and $successCount -eq 0) {
        Write-Host "❌ Failed to deactivate $failCount group(s)" -ForegroundColor Red
    }

    Write-Host ""

    # Ask if user wants to manage more groups
    do {
        [Console]::CursorVisible = $true
        $userInput = Read-PIMInput -Prompt "Would you like to manage more groups? (Y/N)" -ControlsText $script:ControlMessages['Exit']
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
        return
    } else {
        Write-Host "❌ No group management workflows available." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Check back later when groups are approved or activated." -ForegroundColor Gray
        Write-Host ""
        Write-Host "$(Get-QuitShortcutText)" -ForegroundColor Magenta

        [Console]::CursorVisible = $false
        do {
            $key = [Console]::ReadKey($true)
            if (Test-QuitShortcut -Key $key) {
                Invoke-GroupsPIMExit
            }
        } while ($true)
    }
}

function Start-GroupsPIMRoleManagement {
    param(
        [string]$CurrentUserId
    )

    do {
        [Console]::CursorVisible = $false
        Clear-Host
        Show-GroupsPIMHeader

        $menuItems = @(
            "Activate Groups",
            "Deactivate Groups"
        )

        $selectedIndices = Show-CheckboxMenu -Items $menuItems -Title "🔄 Choose Action" -Prompt "Use arrow keys to navigate, SPACE to toggle selection, ENTER to confirm:" -SingleSelection -ShowBack -HeaderStyle "Groups"

        # Back returns to workflow selector
        if ($selectedIndices -eq "BACK") {
            return
        }

        if ($selectedIndices.Count -eq 0) {
            return
        }

        $selectedIndex = $selectedIndices[0]
        $selectedAction = $menuItems[$selectedIndex]

        [Console]::CursorVisible = $false

        if ($selectedAction -eq "Activate Groups") {
            Clear-Host
            Show-GroupsPIMHeader
            Write-Host ""
            Write-Host "🔄 Loading eligible groups..." -ForegroundColor Cyan -NoNewline
            $eligibleGroups = Get-EligibleGroupsOptimized -CurrentUserId $CurrentUserId
            if ($eligibleGroups.Count -gt 0) {
                Write-Host " ✅ $($eligibleGroups.Count) found" -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host ""
            }
            Start-GroupActivationWorkflow -EligibleGroups $eligibleGroups -CurrentUserId $CurrentUserId
        } elseif ($selectedAction -eq "Deactivate Groups") {
            Clear-Host
            Show-GroupsPIMHeader
            Write-Host ""
            Write-Host "🔄 Loading active groups..." -ForegroundColor Cyan -NoNewline
            $activeGroups = Get-ActiveGroupsOptimized -CurrentUserId $CurrentUserId
            if ($activeGroups.Count -gt 0) {
                Write-Host " ✅ $($activeGroups.Count) found" -ForegroundColor Green
            } else {
                Write-Host ""
            }
            Start-GroupDeactivationWorkflow -ActiveGroups $activeGroups -CurrentUserId $CurrentUserId
        }
    } while ($true)
}

function Start-GroupsPIMWorkflow {
    $script:CurrentWorkflow = 'Groups'

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

    # Only need Microsoft.Graph.Authentication for REST calls via Invoke-MgGraphRequest
    $requiredGraphModules = @(
        "Microsoft.Graph.Authentication"
    )

    Clear-Host
    Write-Host ""
    Write-Host "[ P I M   G R O U P S ]" -ForegroundColor Magenta
    Write-Host "    with PowerShell" -ForegroundColor DarkGray
    Write-Host ""

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

        Import-Module $module -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "  ✓ All modules ready!" -ForegroundColor Green
    Write-Host ""

    # Authenticate to Microsoft Graph with group-specific scopes
    [Console]::CursorVisible = $false

    try {
        $scopes = @(
            'PrivilegedEligibilitySchedule.Read.AzureADGroup',
            'PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup',
            'PrivilegedAccess.Read.AzureADGroup',
            'PrivilegedAccess.ReadWrite.AzureADGroup',
            'RoleManagementPolicy.Read.AzureADGroup',
            'User.Read'
        )
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
    } catch {
        Write-Host "❌ Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Press Enter to continue..." -ForegroundColor Yellow
        Read-Host
        return
    }

    # Start the PIM group management workflow
    [Console]::CursorVisible = $true
    Start-GroupsPIMRoleManagement -CurrentUserId $currentUserId

    # Cleanup
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

# ========================= Entra PIM Workflow =========================

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
        "Az.Accounts",
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

        Import-Module $module -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "  ✓ All modules ready!" -ForegroundColor Green
    Write-Host ""

    # Authenticate to Microsoft Graph
    [Console]::CursorVisible = $false

    try {
        $scopes = @(
            'RoleAssignmentSchedule.ReadWrite.Directory',
            'RoleEligibilitySchedule.ReadWrite.Directory',
            'RoleManagement.Read.Directory',
            'RoleManagementPolicy.Read.Directory'
        )
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

# ========================= Prerequisites Installation =========================
function Install-Prerequisites {
    $allModules = @(
        "Az.Accounts",
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Identity.DirectoryManagement",
        "Microsoft.Graph.Identity.Governance"
    )

    $modulesToInstall = @()
    foreach ($module in $allModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            $modulesToInstall += $module
        }
    }

    if ($modulesToInstall.Count -eq 0) {
        return
    }

    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  Installing Prerequisites" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The following modules need to be installed:" -ForegroundColor Yellow
    foreach ($module in $modulesToInstall) {
        Write-Host "  - $module" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Installing modules... (this may take a few minutes)" -ForegroundColor Cyan
    Write-Host ""

    $barWidth = 30
    $currentModule = 0
    $totalModules = $modulesToInstall.Count

    foreach ($module in $modulesToInstall) {
        $currentModule++
        $percent = [math]::Floor(($currentModule / $totalModules) * 100)
        $filled = [math]::Floor(($currentModule / $totalModules) * $barWidth)
        $empty = $barWidth - $filled
        $bar = "█" * $filled + "░" * $empty

        Write-Host "  [$bar] $percent% " -NoNewline -ForegroundColor Yellow
        Write-Host "Installing: " -NoNewline -ForegroundColor Gray
        Write-Host "$module" -ForegroundColor White

        try {
            Install-Module $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "  ❌ Failed to install $module : $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Please run manually: Install-Module $module -Scope CurrentUser -Force" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press Enter to exit..." -ForegroundColor Yellow
            Read-Host
            exit
        }
    }

    Write-Host ""
    Write-Host "✓ All prerequisites installed successfully!" -ForegroundColor Green
    Write-Host ""
    Start-Sleep -Seconds 2
}

# ========================= Main Entry Point =========================

# Cleanup function for graceful exit
function Invoke-GracefulExit {
    param([string]$Reason = "Exiting...")

    [Console]::CursorVisible = $true
    # Restore Ctrl+C default behavior before exiting
    [Console]::TreatControlCAsInput = $false
    Clear-Host
    Write-Host $Reason -ForegroundColor Yellow

    # Disconnect from Microsoft Graph if connected
    try {
        $mgContext = Get-MgContext -ErrorAction SilentlyContinue
        if ($mgContext) {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Write-Host "✅ Disconnected from Microsoft Graph." -ForegroundColor Green
        }
    } catch { }

    # Disconnect from Azure if connected
    try {
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        if ($azContext) {
            Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
            Clear-AzContext -Force -ErrorAction SilentlyContinue | Out-Null
            Write-Host "✅ Disconnected from Azure." -ForegroundColor Green
        }
    } catch { }

    Write-Host ""
    exit 0
}

# Install prerequisites before starting
Install-Prerequisites

# Main loop - no try/finally needed since exit functions handle cleanup
do {
    $workflow = Show-WorkflowSelector

    switch ($workflow) {
        'Entra' {
            Start-EntraPIMWorkflow
        }
        'Azure' {
            Start-AzurePIMWorkflow
        }
        'Groups' {
            Start-GroupsPIMWorkflow
        }
        'Quit' {
            Invoke-GracefulExit -Reason "Exiting..."
        }
    }
} while ($true)
