<#
.SYNOPSIS
    Activates Azure AD PIM group assignments via Microsoft Graph API.

.DESCRIPTION
    This script provides PowerShell-based PIM group activation functionality similar to pimcli.
    It authenticates to Microsoft Graph, retrieves eligible group assignments, and activates them.

.PARAMETER GroupIds
    Optional array of specific Group IDs to activate. If not provided, shows interactive selection.

.PARAMETER Justification
    Required justification text for the activation request.

.PARAMETER Duration
    ISO 8601 duration for the activation (e.g., "PT1H" for 1 hour, "PT8H" for 8 hours).
    If not specified, uses the maximum allowed duration from the group's policy.

.PARAMETER TicketSystem
    Optional ticket system name (e.g., "ServiceNow", "Jira").

.PARAMETER TicketNumber
    Optional ticket number for the activation request.

.PARAMETER TenantId
    Azure AD Tenant ID. If not provided, uses common endpoint.

.PARAMETER ClientId
    Application (client) ID for authentication. Defaults to Microsoft Graph PowerShell.

.EXAMPLE
    # Interactive mode - select groups from a list
    .\Invoke-PIMGroupActivation.ps1 -Justification "Daily work tasks"

.EXAMPLE
    # Activate specific groups
    .\Invoke-PIMGroupActivation.ps1 -GroupIds @("group-id-1", "group-id-2") -Justification "Project work" -Duration "PT4H"

.EXAMPLE
    # With ticket information
    .\Invoke-PIMGroupActivation.ps1 -Justification "INC123456" -TicketSystem "ServiceNow" -TicketNumber "INC123456"

.NOTES
    Author: Generated from pimcli Go implementation
    Requires: Microsoft.Graph PowerShell module or direct Graph API access
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$GroupIds,

    [Parameter(Mandatory = $true)]
    [string]$Justification,

    [Parameter()]
    [string]$Duration,

    [Parameter()]
    [string]$TicketSystem,

    [Parameter()]
    [string]$TicketNumber,

    [Parameter()]
    [string]$TenantId,

    [Parameter()]
    [string]$ClientId = "14d82eec-204b-4c2f-b7e8-296a70dab67e" # Microsoft Graph PowerShell
)

#region Configuration
$ErrorActionPreference = "Stop"
$script:GraphBaseUrl = "https://graph.microsoft.com/v1.0"
$script:DefaultDuration = "PT1H"
$script:MaxWaitTime = 300  # 5 minutes in seconds
$script:PollInterval = 5   # seconds
#endregion

#region Authentication Functions

# Global variable to store assembly paths
$script:MSALAssemblyPaths = @{}
$script:MSALHelperCompiled = $false

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

public class PIMGroupBrowserAuth
{
    public static string GetAccessToken(string clientId, string[] scopes, string tenantId = null)
    {
        try
        {
            var task = Task.Run(async () => await GetAccessTokenAsync(clientId, scopes, tenantId));
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

    private static async Task<string> GetAccessTokenAsync(string clientId, string[] scopes, string tenantId)
    {
        // Use system browser with localhost redirect - must match app registration
        var builder = PublicClientApplicationBuilder.Create(clientId)
            .WithRedirectUri("http://localhost");

        // Add tenant ID if provided
        if (!string.IsNullOrEmpty(tenantId))
        {
            builder = builder.WithAuthority(string.Format("https://login.microsoftonline.com/{0}", tenantId));
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
                tokenBuilder = tokenBuilder.WithExtraQueryParameters(string.Format("domain_hint={0}", tenantId));
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
        $null = [PIMGroupBrowserAuth]
        $script:MSALHelperCompiled = $true
        return $true
    } catch {
        # Type doesn't exist, compile it
    }

    Add-Type -ReferencedAssemblies $referencedAssemblies -TypeDefinition $code -Language CSharp -ErrorAction Stop -IgnoreWarnings 3>$null

    $script:MSALHelperCompiled = $true
    return $true
}

function Get-PIMGroupBrowserAccessToken {
    <#
    .SYNOPSIS
        Gets an access token using browser-based authentication (no WAM).
    #>
    [CmdletBinding()]
    param(
        [string[]]$Scopes
    )

    # Ensure MSAL helper is compiled
    if (-not $script:MSALHelperCompiled) {
        $null = Initialize-MSALHelper
    }

    $clientId = if ($ClientId) { $ClientId } else { "14d82eec-204b-4c2f-b7e8-296a70dab67e" }

    # Build scopes with Graph prefix
    $scopeArray = $Scopes | ForEach-Object {
        if ($_ -notlike "https://*") { "https://graph.microsoft.com/$_" } else { $_ }
    }

    $accessToken = [PIMGroupBrowserAuth]::GetAccessToken($clientId, $scopeArray, $TenantId)
    return $accessToken
}

function Connect-PIMGraph {
    <#
    .SYNOPSIS
        Authenticates to Microsoft Graph using browser-based login (no WAM).
    #>
    [CmdletBinding()]
    param(
        [string]$TenantId,
        [string]$ClientId
    )

    Write-Host "🔐 Authenticating to Microsoft Graph..." -ForegroundColor Cyan

    # Load MSAL assemblies
    $msalLoaded = Initialize-MSALAssemblies
    if (-not $msalLoaded) {
        throw "Failed to load MSAL assemblies. Ensure the Microsoft.Identity.Client NuGet package is installed or the Az.Accounts module is available."
    }

    # Compile the C# browser auth helper
    $null = Initialize-MSALHelper

    $scopes = @(
        "PrivilegedEligibilitySchedule.Read.AzureADGroup",
        "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup",
        "PrivilegedAccess.Read.AzureADGroup",
        "PrivilegedAccess.ReadWrite.AzureADGroup",
        "RoleManagementPolicy.Read.AzureADGroup",
        "User.Read"
    )

    if ($ClientId) {
        Write-Host "  Using app registration: $ClientId" -ForegroundColor Gray
    } else {
        Write-Host "  Using default Microsoft Graph PowerShell client" -ForegroundColor Gray
    }
    if ($TenantId) {
        Write-Host "  Tenant: $TenantId" -ForegroundColor Gray
    }

    Write-Host "  Opening browser for authentication..." -ForegroundColor Cyan
    Write-Host "  Waiting for authentication response..." -ForegroundColor Yellow

    $script:AccessToken = Get-PIMGroupBrowserAccessToken -Scopes $scopes

    if (-not $script:AccessToken) {
        throw "Failed to get access token from browser authentication"
    }

    Write-Host "✅ Authenticated via browser" -ForegroundColor Green
}

function Invoke-PIMGraphRequest {
    <#
    .SYNOPSIS
        Makes a request to Microsoft Graph API using direct REST calls.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [ValidateSet("GET", "POST", "PATCH", "DELETE")]
        [string]$Method = "GET",

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [hashtable]$Headers = @{}
    )

    $fullUri = if ($Uri.StartsWith("http")) { $Uri } else { "$script:GraphBaseUrl$Uri" }
    $requestHeaders = @{
        "Authorization" = "Bearer $script:AccessToken"
        "Content-Type" = "application/json"
        "ConsistencyLevel" = "eventual"
    }
    foreach ($key in $Headers.Keys) {
        $requestHeaders[$key] = $Headers[$key]
    }

    $params = @{
        Method = $Method
        Uri = $fullUri
        Headers = $requestHeaders
    }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    return Invoke-RestMethod @params
}
#endregion

#region Helper Functions
function ConvertTo-ISO8601Duration {
    <#
    .SYNOPSIS
        Converts human-friendly duration input to ISO 8601 duration format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DurationInput
    )

    $DurationInput = $DurationInput.Trim().ToLower()

    # Already ISO 8601 format (e.g., PT1H, PT30M, PT4H30M)
    if ($DurationInput -match '^pt\d') {
        return $DurationInput.ToUpper()
    }

    $hours = 0
    $minutes = 0

    # Match patterns like "4h30m", "2h", "30m", "1h 30m"
    if ($DurationInput -match '(\d+)\s*h') {
        $hours = [int]$Matches[1]
    }
    if ($DurationInput -match '(\d+)\s*m') {
        $minutes = [int]$Matches[1]
    }

    # If just a number, treat as hours
    if ($hours -eq 0 -and $minutes -eq 0 -and $DurationInput -match '^\d+$') {
        $hours = [int]$DurationInput
    }

    if ($hours -eq 0 -and $minutes -eq 0) {
        Write-Warning "Could not parse duration '$DurationInput', defaulting to 1 hour"
        return "PT1H"
    }

    $result = "PT"
    if ($hours -gt 0) { $result += "${hours}H" }
    if ($minutes -gt 0) { $result += "${minutes}M" }
    return $result
}
#endregion

#region PIM Functions
function Get-CurrentUser {
    <#
    .SYNOPSIS
        Gets the current authenticated user's information.
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Getting current user information..."
    $user = Invoke-PIMGraphRequest -Uri "/me" -Method GET
    return $user
}

function Get-PIMGroupEligibleAssignments {
    <#
    .SYNOPSIS
        Gets all PIM group eligible assignments for the current user.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId
    )

    Write-Host "📋 Fetching eligible group assignments..." -ForegroundColor Cyan

    $allAssignments = @()
    $filter = "principalId eq '$UserId'"
    $uri = "/identityGovernance/privilegedAccess/group/eligibilitySchedules?`$filter=$filter&`$expand=group,principal"

    do {
        $response = Invoke-PIMGraphRequest -Uri $uri -Method GET
        
        if ($response.value) {
            $allAssignments += $response.value
        }

        $uri = $response.'@odata.nextLink'
    } while ($uri)

    Write-Host "✅ Found $($allAssignments.Count) eligible group(s)" -ForegroundColor Green
    return $allAssignments
}

function Get-PIMGroupActiveAssignments {
    <#
    .SYNOPSIS
        Gets all active PIM group assignments for the current user.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId
    )

    Write-Verbose "Fetching active group assignments..."

    $allAssignments = @()
    $filter = "principalId eq '$UserId'"
    $uri = "/identityGovernance/privilegedAccess/group/assignmentScheduleInstances?`$filter=$filter&`$expand=group,principal"

    do {
        $response = Invoke-PIMGraphRequest -Uri $uri -Method GET
        
        if ($response.value) {
            $allAssignments += $response.value
        }

        $uri = $response.'@odata.nextLink'
    } while ($uri)

    # Build lookup hashtable
    $activeMap = @{}
    foreach ($assignment in $allAssignments) {
        $key = "$($assignment.groupId):$($assignment.accessId)"
        $activeMap[$key] = $true
    }

    return $activeMap
}

function Get-PIMGroupMaxDuration {
    <#
    .SYNOPSIS
        Gets the maximum activation duration for a PIM group.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupId
    )

    Write-Verbose "Getting maximum duration for group $GroupId..."

    try {
        $filter = "scopeId eq '$GroupId' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
        $uri = "/policies/roleManagementPolicyAssignments?`$filter=$filter&`$expand=policy(`$expand=rules)"
        
        $response = Invoke-PIMGraphRequest -Uri $uri -Method GET

        if (-not $response.value -or $response.value.Count -eq 0) {
            Write-Verbose "No policy found for group $GroupId, using default duration"
            return $script:DefaultDuration
        }

        $policy = $response.value[0].policy
        if (-not $policy -or -not $policy.rules) {
            return $script:DefaultDuration
        }

        # Find the expiration rule
        $expirationRule = $policy.rules | Where-Object { $_.id -eq "Expiration_EndUser_Assignment" }
        
        if ($expirationRule -and $expirationRule.maximumDuration) {
            return $expirationRule.maximumDuration
        }

        return $script:DefaultDuration
    }
    catch {
        Write-Warning "Failed to get max duration for group $GroupId`: $_"
        return $script:DefaultDuration
    }
}

function Get-PIMGroupRequiresTicket {
    <#
    .SYNOPSIS
        Checks if a PIM group requires ticket information for activation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupId
    )

    try {
        $filter = "scopeId eq '$GroupId' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
        $uri = "/policies/roleManagementPolicyAssignments?`$filter=$filter&`$expand=policy(`$expand=rules)"
        
        $response = Invoke-PIMGraphRequest -Uri $uri -Method GET

        if (-not $response.value -or $response.value.Count -eq 0) {
            return $false
        }

        $policy = $response.value[0].policy
        if (-not $policy -or -not $policy.rules) {
            return $false
        }

        # Find the enablement rule
        $enablementRule = $policy.rules | Where-Object { $_.id -eq "Enablement_EndUser_Assignment" }
        
        if ($enablementRule -and $enablementRule.enabledRules) {
            return $enablementRule.enabledRules -contains "Ticketing"
        }

        return $false
    }
    catch {
        Write-Verbose "Failed to check ticket requirement for group $GroupId`: $_"
        return $false
    }
}

function Submit-PIMGroupActivation {
    <#
    .SYNOPSIS
        Submits a PIM group activation request.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PrincipalId,
        
        [Parameter(Mandatory)]
        [string]$GroupId,
        
        [Parameter(Mandatory)]
        [string]$Justification,
        
        [Parameter(Mandatory)]
        [string]$Duration,
        
        [Parameter()]
        [string]$TicketSystem,
        
        [Parameter()]
        [string]$TicketNumber
    )

    $body = @{
        accessId = "member"
        principalId = $PrincipalId
        groupId = $GroupId
        action = "selfActivate"
        justification = $Justification
        scheduleInfo = @{
            startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            expiration = @{
                type = "afterDuration"
                duration = $Duration
            }
        }
    }

    if ($TicketSystem -or $TicketNumber) {
        $body.ticketInfo = @{}
        if ($TicketSystem) { $body.ticketInfo.ticketSystem = $TicketSystem }
        if ($TicketNumber) { $body.ticketInfo.ticketNumber = $TicketNumber }
    }

    $uri = "/identityGovernance/privilegedAccess/group/assignmentScheduleRequests"
    $response = Invoke-PIMGraphRequest -Uri $uri -Method POST -Body $body

    return @{
        RequestId = $response.id
        Status = $response.status
    }
}

function Get-PIMGroupRequestStatus {
    <#
    .SYNOPSIS
        Gets the status of a PIM group activation request.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RequestId
    )

    $uri = "/identityGovernance/privilegedAccess/group/assignmentScheduleRequests/$RequestId"
    $response = Invoke-PIMGraphRequest -Uri $uri -Method GET

    $isComplete = $response.status -in @("Provisioned", "Revoked", "Denied", "Failed", "Canceled")
    $needsApproval = $response.status -eq "PendingApproval"

    return @{
        RequestId = $response.id
        Status = $response.status
        IsComplete = $isComplete
        NeedsApproval = $needsApproval
        GroupId = $response.groupId
    }
}

function Wait-PIMGroupRequestCompletion {
    <#
    .SYNOPSIS
        Waits for a PIM group activation request to complete.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RequestId,
        
        [Parameter()]
        [int]$MaxWaitSeconds = 300,
        
        [Parameter()]
        [int]$PollIntervalSeconds = 5
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($stopwatch.Elapsed.TotalSeconds -lt $MaxWaitSeconds) {
        $status = Get-PIMGroupRequestStatus -RequestId $RequestId

        if ($status.IsComplete -or $status.NeedsApproval) {
            return $status
        }

        Start-Sleep -Seconds $PollIntervalSeconds
    }

    throw "Timeout waiting for request $RequestId to complete"
}

function Invoke-PIMGroupActivation {
    <#
    .SYNOPSIS
        Activates a single PIM group assignment.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Assignment,
        
        [Parameter(Mandatory)]
        [string]$Justification,
        
        [Parameter()]
        [string]$Duration,
        
        [Parameter()]
        [string]$TicketSystem,
        
        [Parameter()]
        [string]$TicketNumber
    )

    $groupName = $Assignment.group.displayName
    $groupId = $Assignment.groupId
    $principalId = $Assignment.principalId

    Write-Host "  🔄 Activating: $groupName" -ForegroundColor White

    try {
        Write-Host "    📤 Submitting activation request (Duration: $Duration)..." -ForegroundColor Gray

        $result = Submit-PIMGroupActivation `
            -PrincipalId $principalId `
            -GroupId $groupId `
            -Justification $Justification `
            -Duration $Duration `
            -TicketSystem $TicketSystem `
            -TicketNumber $TicketNumber

        Write-Host "    ⏳ Waiting for completion..." -ForegroundColor Gray

        $finalStatus = Wait-PIMGroupRequestCompletion -RequestId $result.RequestId

        if ($finalStatus.NeedsApproval) {
            Write-Host "  ⚠️  $groupName - Pending Approval" -ForegroundColor Yellow
            return @{
                GroupName = $groupName
                GroupId = $groupId
                Status = "PendingApproval"
                Success = $true
                NeedsApproval = $true
            }
        }
        elseif ($finalStatus.Status -eq "Provisioned") {
            Write-Host "  ✅ $groupName - Activated Successfully" -ForegroundColor Green
            return @{
                GroupName = $groupName
                GroupId = $groupId
                Status = $finalStatus.Status
                Success = $true
                NeedsApproval = $false
            }
        }
        else {
            Write-Host "  ❌ $groupName - $($finalStatus.Status)" -ForegroundColor Red
            return @{
                GroupName = $groupName
                GroupId = $groupId
                Status = $finalStatus.Status
                Success = $false
                NeedsApproval = $false
            }
        }
    }
    catch {
        Write-Host "  ❌ $groupName - Error: $_" -ForegroundColor Red
        return @{
            GroupName = $groupName
            GroupId = $groupId
            Status = "Failed"
            Success = $false
            Error = $_.Exception.Message
            NeedsApproval = $false
        }
    }
}
#endregion

#region Interactive Selection
function Show-GroupSelection {
    <#
    .SYNOPSIS
        Shows an interactive menu for selecting groups to activate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$EligibleGroups,
        
        [Parameter(Mandatory)]
        [hashtable]$ActiveMap
    )

    Write-Host "`n📋 Available Groups for Activation:" -ForegroundColor Cyan
    Write-Host ("─" * 60)

    $selectableGroups = @()
    $index = 1

    foreach ($group in $EligibleGroups) {
        $key = "$($group.groupId):$($group.accessId)"
        $isActive = $ActiveMap.ContainsKey($key)
        $groupName = $group.group.displayName
        
        if ($isActive) {
            Write-Host ("  [{0,2}] {1} (Already Active)" -f "-", $groupName) -ForegroundColor DarkGray
        }
        else {
            Write-Host ("  [{0,2}] {1}" -f $index, $groupName) -ForegroundColor White
            $selectableGroups += @{
                Index = $index
                Assignment = $group
            }
            $index++
        }
    }

    if ($selectableGroups.Count -eq 0) {
        Write-Host "`n✅ All groups are already active!" -ForegroundColor Green
        return @()
    }

    Write-Host ("`n" + "─" * 60)
    Write-Host "Enter group numbers to activate (comma-separated, or 'all' for all, 'q' to quit):" -ForegroundColor Cyan
    $selection = Read-Host "Selection"

    if ($selection -eq 'q' -or $selection -eq 'quit') {
        return @()
    }

    if ($selection -eq 'all' -or $selection -eq 'a') {
        return $selectableGroups.Assignment
    }

    $selectedIndices = $selection -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    
    $selectedGroups = @()
    foreach ($idx in $selectedIndices) {
        $match = $selectableGroups | Where-Object { $_.Index -eq $idx }
        if ($match) {
            $selectedGroups += $match.Assignment
        }
    }

    return $selectedGroups
}
#endregion

#region Main Execution
function Main {
    [CmdletBinding()]
    param()

    Write-Host ("`n" + "═" * 60) -ForegroundColor Cyan
    Write-Host "  PIM Group Activation - PowerShell Edition" -ForegroundColor Cyan
    Write-Host ("═" * 60) -ForegroundColor Cyan

    # Authenticate
    Connect-PIMGraph -TenantId $TenantId -ClientId $ClientId

    # Get current user
    $currentUser = Get-CurrentUser
    $userId = $currentUser.id
    $userDisplayName = $currentUser.displayName
    Write-Host "👤 Logged in as: $userDisplayName ($($currentUser.userPrincipalName))" -ForegroundColor Green

    # Get eligible assignments
    $eligibleAssignments = Get-PIMGroupEligibleAssignments -UserId $userId

    if ($eligibleAssignments.Count -eq 0) {
        Write-Host "⚠️  No eligible group assignments found." -ForegroundColor Yellow
        return
    }

    # Get active assignments
    Write-Host "🔍 Checking active assignments..." -ForegroundColor Cyan
    $activeMap = Get-PIMGroupActiveAssignments -UserId $userId

    # Determine which groups to activate
    $groupsToActivate = @()

    if ($GroupIds -and $GroupIds.Count -gt 0) {
        # Activate specific groups
        foreach ($groupId in $GroupIds) {
            $assignment = $eligibleAssignments | Where-Object { $_.groupId -eq $groupId }
            if ($assignment) {
                $key = "$($assignment.groupId):$($assignment.accessId)"
                if ($activeMap.ContainsKey($key)) {
                    Write-Host "ℹ️  $($assignment.group.displayName) is already active, skipping." -ForegroundColor Yellow
                }
                else {
                    $groupsToActivate += $assignment
                }
            }
            else {
                Write-Warning "Group ID '$groupId' not found in eligible assignments"
            }
        }
    }
    else {
        # Interactive selection
        $groupsToActivate = Show-GroupSelection -EligibleGroups $eligibleAssignments -ActiveMap $activeMap
    }

    if ($groupsToActivate.Count -eq 0) {
        Write-Host "`n⚠️  No groups selected for activation." -ForegroundColor Yellow
        return
    }

    # Check for ticket requirements
    $ticketRequired = $false
    $groupsRequiringTickets = @()
    
    foreach ($group in $groupsToActivate) {
        if (Get-PIMGroupRequiresTicket -GroupId $group.groupId) {
            $ticketRequired = $true
            $groupsRequiringTickets += $group.group.displayName
        }
    }

    if ($ticketRequired -and (-not $TicketNumber)) {
        Write-Host "`n🎫 The following groups require ticket information:" -ForegroundColor Yellow
        $groupsRequiringTickets | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
        
        if (-not $TicketSystem) {
            $TicketSystem = Read-Host "Enter ticket system (e.g., ServiceNow, Jira)"
        }
        $TicketNumber = Read-Host "Enter ticket number"
    }

    # Prompt for duration if not provided
    if (-not $Duration) {
        Write-Host "`n⏱️  Enter activation duration (e.g., 1h, 2h, 30m, 4h30m):" -ForegroundColor Cyan
        $durationInput = Read-Host "Duration"
        if (-not $durationInput) {
            $durationInput = "1h"
            Write-Host "    Using default: 1 hour" -ForegroundColor Gray
        }
        # Parse human-friendly input to ISO 8601 duration
        $Duration = ConvertTo-ISO8601Duration -DurationInput $durationInput
        Write-Host "    📎 Duration: $Duration" -ForegroundColor Gray
    }

    # Activate groups
    Write-Host "`n🚀 Activating $($groupsToActivate.Count) group(s)..." -ForegroundColor Cyan
    Write-Host ("─" * 60)

    $results = @()
    foreach ($assignment in $groupsToActivate) {
        $result = Invoke-PIMGroupActivation `
            -Assignment $assignment `
            -Justification $Justification `
            -Duration $Duration `
            -TicketSystem $TicketSystem `
            -TicketNumber $TicketNumber
        
        $results += $result
    }

    # Summary
    Write-Host ("`n" + "═" * 60) -ForegroundColor Cyan
    Write-Host "  Activation Summary" -ForegroundColor Cyan
    Write-Host ("═" * 60) -ForegroundColor Cyan

    $successful = $results | Where-Object { $_.Success -and -not $_.NeedsApproval }
    $pendingApproval = $results | Where-Object { $_.NeedsApproval }
    $failed = $results | Where-Object { -not $_.Success }

    if ($successful.Count -gt 0) {
        Write-Host "✅ Successfully Activated ($($successful.Count)):" -ForegroundColor Green
        $successful | ForEach-Object { Write-Host "   - $($_.GroupName)" -ForegroundColor Green }
    }

    if ($pendingApproval.Count -gt 0) {
        Write-Host "⚠️  Pending Approval ($($pendingApproval.Count)):" -ForegroundColor Yellow
        $pendingApproval | ForEach-Object { Write-Host "   - $($_.GroupName)" -ForegroundColor Yellow }
    }

    if ($failed.Count -gt 0) {
        Write-Host "❌ Failed ($($failed.Count)):" -ForegroundColor Red
        $failed | ForEach-Object { Write-Host "   - $($_.GroupName): $($_.Error)" -ForegroundColor Red }
    }

    Write-Host ("`n" + "═" * 60) -ForegroundColor Cyan

    # Return results for pipeline usage
    return $results
}

# Execute main function
Main
#endregion

