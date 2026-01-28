#Requires -Version 7.0

# Entra-PIM PowerShell Module
# Simple wrapper to run the PIM management script

function Get-EntraPIMHelp {
    <#
    .SYNOPSIS
        Displays help information for Entra-PIM commands.

    .DESCRIPTION
        Shows all available Entra-PIM commands with examples and usage information.
        Includes detailed guidance on configuration options.

    .EXAMPLE
        Get-EntraPIMHelp
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              ENTRA-PIM HELP & COMMANDS                       ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    Write-Host "BASIC USAGE" -ForegroundColor Yellow
    Write-Host "═══════════" -ForegroundColor Yellow
    Write-Host "  Start-EntraPIM" -ForegroundColor White
    Write-Host "    Launch the Entra-PIM role management tool" -ForegroundColor Gray
    Write-Host "    Uses default Microsoft Graph authentication`n" -ForegroundColor Gray

    Write-Host "CONFIGURATION COMMANDS" -ForegroundColor Yellow
    Write-Host "══════════════════════" -ForegroundColor Yellow

    Write-Host "`n  Configure-EntraPIM" -ForegroundColor White
    Write-Host "    Set up custom app registration for your organization" -ForegroundColor Gray
    Write-Host "    • Prompts for ClientId and TenantId" -ForegroundColor DarkGray
    Write-Host "    • Saves as environment variables (persists across sessions)" -ForegroundColor DarkGray
    Write-Host "    • On macOS: Offers to add to PowerShell profile" -ForegroundColor DarkGray
    Write-Host "    • After configuration, just run: Start-EntraPIM`n" -ForegroundColor DarkGray

    Write-Host "  Clear-EntraPIMConfig" -ForegroundColor White
    Write-Host "    Remove saved configuration and return to default auth" -ForegroundColor Gray
    Write-Host "    • Removes environment variables permanently" -ForegroundColor DarkGray
    Write-Host "    • On macOS: Offers to remove from PowerShell profile`n" -ForegroundColor DarkGray

    Write-Host "ADVANCED USAGE" -ForegroundColor Yellow
    Write-Host "══════════════" -ForegroundColor Yellow
    Write-Host "  Start-EntraPIM -ClientId <id> -TenantId <id>" -ForegroundColor White
    Write-Host "    Use custom app registration for a single session" -ForegroundColor Gray
    Write-Host "    (Does not save configuration)`n" -ForegroundColor DarkGray

    Write-Host "CONFIGURATION WORKFLOW" -ForegroundColor Yellow
    Write-Host "══════════════════════" -ForegroundColor Yellow
    Write-Host "  1. Configure once:" -ForegroundColor White
    Write-Host "     Configure-EntraPIM" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Use anytime:" -ForegroundColor White
    Write-Host "     Start-EntraPIM" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Remove config (switch back to default):" -ForegroundColor White
    Write-Host "     Clear-EntraPIMConfig`n" -ForegroundColor Cyan

    Write-Host "APP REGISTRATION REQUIREMENTS" -ForegroundColor Yellow
    Write-Host "═════════════════════════════" -ForegroundColor Yellow
    Write-Host "  • Platform: Mobile and desktop applications" -ForegroundColor Gray
    Write-Host "  • Redirect URI: http://localhost" -ForegroundColor Gray
    Write-Host "  • Allow public client flows: Yes" -ForegroundColor Gray
    Write-Host "  • API Permissions (delegated):" -ForegroundColor Gray
    Write-Host "    - User.Read" -ForegroundColor DarkGray
    Write-Host "    - RoleAssignmentSchedule.ReadWrite.Directory" -ForegroundColor DarkGray
    Write-Host "    - RoleEligibilitySchedule.ReadWrite.Directory" -ForegroundColor DarkGray
    Write-Host "    - RoleManagement.Read.Directory" -ForegroundColor DarkGray
    Write-Host "    - RoleManagementPolicy.Read.Directory`n" -ForegroundColor DarkGray

    Write-Host "ADDITIONAL HELP" -ForegroundColor Yellow
    Write-Host "═══════════════" -ForegroundColor Yellow
    Write-Host "  Get-Help Start-EntraPIM -Full" -ForegroundColor White
    Write-Host "  Get-Help Configure-EntraPIM -Full" -ForegroundColor White
    Write-Host "  Get-Help Clear-EntraPIMConfig -Full`n" -ForegroundColor White

    Write-Host "PROJECT" -ForegroundColor Yellow
    Write-Host "═══════" -ForegroundColor Yellow
    Write-Host "  GitHub: https://github.com/markorr321/Entra-PIM" -ForegroundColor Cyan
    Write-Host "  Gallery: https://www.powershellgallery.com/packages/Entra-PIM`n" -ForegroundColor Cyan
}

function Configure-EntraPIM {
    <#
    .SYNOPSIS
        Configure Entra-PIM with custom app registration credentials.

    .DESCRIPTION
        Interactively prompts for ClientId and TenantId and saves them as user-level
        environment variables. Once configured, Start-EntraPIM will automatically use
        these credentials without requiring parameters.

    .EXAMPLE
        Configure-EntraPIM
    #>
    [CmdletBinding()]
    param()

    Write-Host "`nEntra-PIM Configuration" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host "`nThis will configure your custom app registration for Entra-PIM."
    Write-Host "These settings will be saved as user-level environment variables.`n"

    # Prompt for ClientId
    $clientId = Read-Host "Enter your App Registration Client ID"
    if ([string]::IsNullOrWhiteSpace($clientId)) {
        Write-Host "ClientId cannot be empty. Configuration cancelled." -ForegroundColor Yellow
        return
    }

    # Prompt for TenantId
    $tenantId = Read-Host "Enter your Tenant ID"
    if ([string]::IsNullOrWhiteSpace($tenantId)) {
        Write-Host "TenantId cannot be empty. Configuration cancelled." -ForegroundColor Yellow
        return
    }

    # Set user-level environment variables
    try {
        [System.Environment]::SetEnvironmentVariable('ENTRAPIM_CLIENTID', $clientId, 'User')
        [System.Environment]::SetEnvironmentVariable('ENTRAPIM_TENANTID', $tenantId, 'User')

        # Also set for current session
        $env:ENTRAPIM_CLIENTID = $clientId
        $env:ENTRAPIM_TENANTID = $tenantId

        Write-Host "`nConfiguration saved successfully!" -ForegroundColor Green
        Write-Host "You can now run Start-EntraPIM without parameters.`n" -ForegroundColor Green

        # macOS-specific handling
        $isRunningOnMac = if ($null -ne $IsMacOS) { $IsMacOS } else { $PSVersionTable.OS -match 'Darwin' }
        if ($isRunningOnMac) {
            Write-Host "macOS Note:" -ForegroundColor Yellow
            Write-Host "Environment variables may not persist across terminal sessions on macOS." -ForegroundColor Gray
            Write-Host "To ensure persistence, add the following to your PowerShell profile:`n" -ForegroundColor Gray
            Write-Host "`$env:ENTRAPIM_CLIENTID = `"$clientId`"" -ForegroundColor Cyan
            Write-Host "`$env:ENTRAPIM_TENANTID = `"$tenantId`"`n" -ForegroundColor Cyan

            Write-Host "Would you like to:" -ForegroundColor Yellow
            Write-Host "  1) Add automatically to PowerShell profile" -ForegroundColor White
            Write-Host "  2) Do it manually later" -ForegroundColor White
            Write-Host ""
            $choice = Read-Host "Enter choice (1 or 2)"

            if ($choice -eq "1") {
                $profilePath = $PROFILE.CurrentUserAllHosts
                if (-not (Test-Path $profilePath)) {
                    New-Item -Path $profilePath -ItemType File -Force | Out-Null
                }

                $profileContent = @"

# Entra-PIM Configuration
`$env:ENTRAPIM_CLIENTID = "$clientId"
`$env:ENTRAPIM_TENANTID = "$tenantId"
"@
                Add-Content -Path $profilePath -Value $profileContent
                Write-Host "`nAdded to PowerShell profile: $profilePath" -ForegroundColor Green
                Write-Host "Configuration will persist across sessions.`n" -ForegroundColor Green
            } else {
                Write-Host "`nYou can add it manually later to: $($PROFILE.CurrentUserAllHosts)`n" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Host "`nFailed to save configuration: $_" -ForegroundColor Red
    }
}

function Clear-EntraPIMConfig {
    <#
    .SYNOPSIS
        Clears the saved Entra-PIM configuration.

    .DESCRIPTION
        Removes the user-level environment variables for ClientId and TenantId.
        On macOS, also offers to remove the configuration from PowerShell profile.
        After clearing, Start-EntraPIM will use the default authentication flow.

    .EXAMPLE
        Clear-EntraPIMConfig
    #>
    [CmdletBinding()]
    param()

    try {
        [System.Environment]::SetEnvironmentVariable('ENTRAPIM_CLIENTID', $null, 'User')
        [System.Environment]::SetEnvironmentVariable('ENTRAPIM_TENANTID', $null, 'User')

        # Also clear from current session
        $env:ENTRAPIM_CLIENTID = $null
        $env:ENTRAPIM_TENANTID = $null

        Write-Host "Entra-PIM configuration cleared successfully." -ForegroundColor Green
        Write-Host "Start-EntraPIM will now use the default authentication flow.`n" -ForegroundColor Green

        # macOS-specific handling - check if profile has the config
        $isRunningOnMac = if ($null -ne $IsMacOS) { $IsMacOS } else { $PSVersionTable.OS -match 'Darwin' }
        if ($isRunningOnMac) {
            $profilePath = $PROFILE.CurrentUserAllHosts
            if (Test-Path $profilePath) {
                $profileContent = Get-Content -Path $profilePath -Raw
                if ($profileContent -match 'ENTRAPIM_CLIENTID' -or $profileContent -match 'ENTRAPIM_TENANTID') {
                    Write-Host "macOS Note:" -ForegroundColor Yellow
                    Write-Host "Configuration found in PowerShell profile." -ForegroundColor Gray
                    Write-Host "Would you like to remove it from your profile? (y/n)" -ForegroundColor Yellow
                    $choice = Read-Host

                    if ($choice -eq 'y' -or $choice -eq 'Y') {
                        # Remove Entra-PIM configuration section from profile
                        $newContent = $profileContent -replace '(?ms)# Entra-PIM Configuration.*?\$env:ENTRAPIM_TENANTID = ".*?"', ''
                        Set-Content -Path $profilePath -Value $newContent.Trim()
                        Write-Host "Removed from PowerShell profile: $profilePath`n" -ForegroundColor Green
                    } else {
                        Write-Host "Profile not modified. You can manually edit: $profilePath`n" -ForegroundColor Gray
                    }
                }
            }
        }
    }
    catch {
        Write-Host "Failed to clear configuration: $_" -ForegroundColor Red
    }
}

function Start-EntraPIM {
    <#
    .SYNOPSIS
        Launches the Entra PIM role management tool.

    .DESCRIPTION
        Opens an interactive console application for managing Microsoft Entra
        PIM role activations and deactivations with browser-based authentication.

        If ClientId and TenantId are not provided as parameters, the function will
        check for environment variables set via Configure-EntraPIM. If neither are
        found, it uses the default authentication flow.

    .PARAMETER ClientId
        Client ID of the app registration to use for delegated auth.
        If not provided, checks ENTRAPIM_CLIENTID environment variable.

    .PARAMETER TenantId
        Tenant ID to use with the specified app registration.
        If not provided, checks ENTRAPIM_TENANTID environment variable.

    .EXAMPLE
        Start-EntraPIM

    .EXAMPLE
        Start-EntraPIM -ClientId "b7463ebe-e5a7-4a1a-ba64-34b99135a27a" -TenantId "51eb883f-451f-4194-b108-4df354b35bf4"
    #>
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = "Client ID of the app registration to use for delegated auth")]
        [string]$ClientId,

        [Parameter(HelpMessage = "Tenant ID to use with the specified app registration")]
        [string]$TenantId
    )

    # Check for environment variables if parameters not provided
    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        $ClientId = $env:ENTRAPIM_CLIENTID
    }
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        $TenantId = $env:ENTRAPIM_TENANTID
    }

    # Run the main script
    $scriptPath = Join-Path $PSScriptRoot "Entra-PIM.ps1"
    & $scriptPath -ClientId $ClientId -TenantId $TenantId
}

Export-ModuleMember -Function 'Start-EntraPIM', 'Configure-EntraPIM', 'Clear-EntraPIMConfig', 'Get-EntraPIMHelp'
