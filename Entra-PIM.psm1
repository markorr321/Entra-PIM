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
        Entra-PIM supports Entra ID roles, Azure Resource roles, and Groups PIM.

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
    Write-Host "    Supports Entra ID roles, Azure Resource roles, and Groups PIM`n" -ForegroundColor Gray

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
    Write-Host "    - RoleManagementPolicy.Read.Directory" -ForegroundColor DarkGray
    Write-Host "  • For Groups PIM (additional):" -ForegroundColor Gray
    Write-Host "    - PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup" -ForegroundColor DarkGray
    Write-Host "    - PrivilegedEligibilitySchedule.Read.AzureADGroup" -ForegroundColor DarkGray
    Write-Host "    - RoleManagementPolicy.Read.AzureADGroup`n" -ForegroundColor DarkGray

    Write-Host "DURATION BEHAVIOR" -ForegroundColor Yellow
    Write-Host "═════════════════" -ForegroundColor Yellow
    Write-Host "  • Each role/group has a policy-defined maximum duration" -ForegroundColor Gray
    Write-Host "  • If your requested duration exceeds a role's max, that role" -ForegroundColor Gray
    Write-Host "    activates for its individual policy maximum" -ForegroundColor Gray
    Write-Host "  • A preview is shown before activation when limits apply`n" -ForegroundColor Gray

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

function Show-UpdateNotification {
    <#
    .SYNOPSIS
        Displays the update notification message.

    .DESCRIPTION
        Shows a formatted notification when a newer version of Entra-PIM
        is available on PowerShell Gallery.

    .PARAMETER CurrentVersion
        The currently installed version.

    .PARAMETER LatestVersion
        The latest version available on PowerShell Gallery.

    .EXAMPLE
        Show-UpdateNotification -CurrentVersion "2.1.0" -LatestVersion "2.2.0"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [version]$CurrentVersion,

        [Parameter(Mandatory)]
        [version]$LatestVersion
    )

    Write-Host ""
    Write-Host "[!] Entra-PIM update available: $CurrentVersion -> $LatestVersion" -ForegroundColor Red
    Write-Host ""

    $response = Read-Host "Update now? (Y/N) [Press Enter to skip]"

    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host ""
        Write-Host "Updating Entra-PIM..." -ForegroundColor Cyan

        try {
            # Detect how the module was installed and use matching update command
            $installedViaPSResource = $null
            $installedViaPowerShellGet = $null
            
            # Check PSResourceGet first
            if (Get-Command Get-InstalledPSResource -ErrorAction SilentlyContinue) {
                $installedViaPSResource = Get-InstalledPSResource -Name Entra-PIM -ErrorAction SilentlyContinue
            }
            
            # Check PowerShellGet
            if (Get-Command Get-InstalledModule -ErrorAction SilentlyContinue) {
                $installedViaPowerShellGet = Get-InstalledModule -Name Entra-PIM -ErrorAction SilentlyContinue
            }
            
            if ($installedViaPSResource) {
                # Installed via PSResourceGet - detect scope from installation path
                $installPath = $installedViaPSResource.InstalledLocation
                # AllUsers paths: Windows="Program Files", macOS/Linux="/usr/local"
                $scope = if ($installPath -match 'Program Files|/usr/local') { 'AllUsers' } else { 'CurrentUser' }
                Update-PSResource -Name Entra-PIM -Scope $scope -Confirm:$false
            }
            elseif ($installedViaPowerShellGet) {
                # Installed via PowerShellGet, use Update-Module
                Update-Module -Name Entra-PIM -Force
            }
            elseif (Get-Command Update-Module -ErrorAction SilentlyContinue) {
                # Fallback to Update-Module if we can't detect installation method
                Update-Module -Name Entra-PIM -Force
            }
            else {
                Write-Host "Update commands not found. Please run manually:" -ForegroundColor Yellow
                Write-Host "  Install-Module -Name Entra-PIM -Force" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Press Enter to continue"
                $null = [Console]::ReadLine()
                return
            }

            Write-Host ""
            Write-Host "Update complete! Please restart PowerShell and run Start-EntraPIM again." -ForegroundColor Green
            Write-Host ""
            Write-Host "Press Enter to Exit"
            $null = [Console]::ReadLine()
            exit
        }
        catch {
            Write-Host ""
            Write-Host "Update failed: $_" -ForegroundColor Red
            Write-Host "Please update manually with:" -ForegroundColor Yellow
            Write-Host "  Update-Module -Name Entra-PIM      (if installed via Install-Module)" -ForegroundColor Yellow
            Write-Host "  Update-PSResource -Name Entra-PIM  (if installed via Install-PSResource)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press Enter to continue anyway"
            $null = [Console]::ReadLine()
        }
    }
    elseif ($response -eq 'N' -or $response -eq 'n') {
        Write-Host "Skipping update." -ForegroundColor Yellow
        Write-Host ""
    }
    else {
        # Just continue
        Write-Host ""
    }
}

function Test-EntraPIMUpdate {
    <#
    .SYNOPSIS
        Checks if a newer version of Entra-PIM is available on PowerShell Gallery.

    .DESCRIPTION
        Performs a quick check for updates on each run.
        Silently handles all errors to not interrupt user experience.

    .EXAMPLE
        Test-EntraPIMUpdate
    #>
    [CmdletBinding()]
    param()

    try {
        # Allow users to disable update checks via environment variable
        if ($env:ENTRAPIM_DISABLE_UPDATE_CHECK -eq 'true') {
            return
        }

        # Get current module version (check loaded module first, then installed)
        $currentModule = Get-Module -Name Entra-PIM |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $currentModule) {
            $currentModule = Get-Module -Name Entra-PIM -ListAvailable |
                Sort-Object Version -Descending |
                Select-Object -First 1
        }

        if (-not $currentModule) {
            return
        }

        $currentVersion = $currentModule.Version

        # Fast version check using URL redirect
        try {
            $url = "https://www.powershellgallery.com/packages/Entra-PIM"
            $latestVersion = $null

            try {
                $null = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 5 -ErrorAction Stop
            } catch {
                if ($_.Exception.Response -and $_.Exception.Response.Headers) {
                    try {
                        $location = $_.Exception.Response.Headers.GetValues('Location') | Select-Object -First 1
                        if ($location) {
                            $versionString = Split-Path -Path $location -Leaf
                            $latestVersion = [version]$versionString
                        } else {
                            return
                        }
                    } catch {
                        return
                    }
                } else {
                    return
                }
            }

            if (-not $latestVersion) {
                return
            }

            if ($currentVersion -lt $latestVersion) {
                Show-UpdateNotification -CurrentVersion $currentVersion -LatestVersion $latestVersion
            }

        } catch {
            return
        }

    } catch {
        return
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

    # Check for module updates
    Test-EntraPIMUpdate

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

# SIG # Begin signature block
# MIIVpQYJKoZIhvcNAQcCoIIVljCCFZICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCNHO8lfxzxCiFd
# CbARdnjm/9G1SdQg1VYYIn/+GTMOuKCCEeAwggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYaMIIEAqADAgECAhBiHW0M
# UgGeO5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5
# NTlaMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzAp
# BgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0G
# CSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjI
# ztNsfvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NV
# DgFigOMYzB2OKhdqfWGVoYW3haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/3
# 6F09fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05Zw
# mRmTnAO5/arnY83jeNzhP06ShdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm
# +qxp4VqpB3MV/h53yl41aHU5pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUe
# dyz8rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz4
# 4MPZ1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBM
# dlyh2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQY
# MBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritU
# pimqF6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNV
# HSUEDDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsG
# A1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1
# YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsG
# AQUFBzAChjpodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2Rl
# U2lnbmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0
# aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURh
# w1aVcdGRP4Wh60BAscjW4HL9hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0Zd
# OaWTsyNyBBsMLHqafvIhrCymlaS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajj
# cw5+w/KeFvPYfLF/ldYpmlG+vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNc
# WbWDRF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalO
# hOfCipnx8CaLZeVme5yELg09Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJs
# zkyeiaerlphwoKx1uHRzNyE6bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z7
# 6mKnzAfZxCl/3dq3dUNw4rg3sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5J
# KdGvspbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHH
# j95Ejza63zdrEcxWLDX6xWls/GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2
# Bev6SivBBOHY+uqiirZtg0y9ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/
# L9Uo2bC5a4CH2RwwggZLMIIEs6ADAgECAhEAh4S8tN9yByR3E9jATIZw9DANBgkq
# hkiG9w0BAQwFADBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1p
# dGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2
# MB4XDTI2MDIyNDAwMDAwMFoXDTI3MDIyNDIzNTk1OVowRDELMAkGA1UEBhMCVVMx
# DzANBgNVBAgMBkthbnNhczERMA8GA1UECgwITWFyayBPcnIxETAPBgNVBAMMCE1h
# cmsgT3JyMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAx9tr2sjXvlV3
# KjWWeg0HYTDicFwZDZv2tI//RO1C9IL7uShmYN0eSeyWZW/GNy7fTOlIJ6poUe4R
# 3/ApsNsw9hpOMXc92BnyDs/UXHMYx2YdOO4XI35IxfhZnZhgIj2acQ0BZ542hmYA
# wtz8c1Xu9xH51eTArmFWHV8angRsuFMVyKQOraWQs37tqOVwXeH3FQIT0mFBTbmE
# NhgyxAGLq8nZMFM+JqVVWeRgvTFO48UZf0BhgH84k2M44CcA9vVML7w4yueg6qD6
# D/k7Opy1OfCR1qxSXI0wZeUXodJvgisDRScKZJfPID6PIxxvoeem4VKkV0y3eBF+
# UtdQ8+NZ7qmlRl2hE6H6efWSRNW2imxeVSg9FgQONnJYhkyJmaio/NnLyDB6PyoC
# DZQaYDiMRRiycHPbYvbas0THWB2NFsgr3h3QZxQfZnNB2F/ZVdNlfbGpxTK53Yhf
# 5XT0iaEat9r82wwjlP9c/PEl1q8G53Pco/ykqBk/V2PfohhuwiXBHb5zL518lCPP
# ZmOCdIqyvkgAUzWymHSiTwm/ZNTNEaHLaktfBJ52G03r7F1YHSxPDJpH84RrBQwN
# WA8olog3uvvWTWImDuQd8PdvhOrluh11pvMWRn+ic6e2E7A4KQr0x4bZoL/gWBTE
# 9tL8AuCJyjxsjiDAbJRxd3Di5Bi7pGsCAwEAAaOCAaYwggGiMB8GA1UdIwQYMBaA
# FA8qyyCHKLjsb0iuK1SmKaoXpM0MMB0GA1UdDgQWBBRlBYoMei+jtIKM2eL9y3kX
# +l6hqzAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggr
# BgEFBQcDAzBKBgNVHSAEQzBBMDUGDCsGAQQBsjEBAgEDAjAlMCMGCCsGAQUFBwIB
# FhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZngQwBBAEwSQYDVR0fBEIwQDA+
# oDygOoY4aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNp
# Z25pbmdDQVIzNi5jcmwweQYIKwYBBQUHAQEEbTBrMEQGCCsGAQUFBzAChjhodHRw
# Oi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2
# LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wGwYDVR0R
# BBQwEoEQbW9yckBvcnIzNjUudGVjaDANBgkqhkiG9w0BAQwFAAOCAYEAQYDywuGV
# M9hgCjKW/Til/gPycxB1XL4OH7/9jV72/HPbBKnwXwiFlgTO+Lo4UEbZNy+WQk60
# u0XtrBIKUbhlapRGQPrl2OKpf9rYOyysg1puVTqnaxY9vevhgB4NVpHqYMi8+Kzp
# a2rXzXyrVdbVNIMn00ZAV6tBTr0fhMt3P4oxF0WYQ/GjfUa1/8O3uqeni36iMyCq
# P7ao9rJgCOgNvEBokRhh7fFC5YVIjMKwvU/7CgbkgjIBHfX4UMxU2BNvCGTR2ZA5
# IznmLsRI/4MEP9LMLV8DQm8wh2P1uCaGANSLQ0EQIZtMEm1i03zBwDOTBLVAo7p+
# 2Pw2q7LEOQni6LeX5AzTnRvHwcisRM3Kpvx+H6wJnL6x7TXZ7YCHhJ4ZTuMWblXJ
# jVKPueEQfIh04x7oVbIV8LNqVyoP9gJZfkmn5IW8cwIFAzFMsNqW1URfArzJ5An9
# xIYCUJbzohgtE71NjqiZPI1k4GxzsyeqTNaXEXnzZEfogAvEmHFMMNXGMYIDGzCC
# AxcCAQEwaTBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2AhEA
# h4S8tN9yByR3E9jATIZw9DANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCD23AQX8Als53LV
# gKpHtNPtlgnK/HRC3ipr+oACQXQsSTANBgkqhkiG9w0BAQEFAASCAgC9WodJPzWo
# vb+coDBe/U2ren7mPpvElnfeo6nOMUe0h48iUH5bs/gM0sqeeFQeIpyL3AJWWWvx
# TzDR/fdiEKlU85IOiU4iWupfWUMwmyeI94+yCJxr19pB0De7+0FNRQAlynoF7ErZ
# VKFZSQEuvxErHggprwJuTSeTKyZ1ffrXGuOQ/IP3+h+EaCvxXWtRNSOMQfgNp5Ni
# xE6Yb4ncnmpdGAtDfTJqsD8V7lsiLhuZD95Ep0TSf5DhM6uc944iWSEnRwCNw6DM
# weV2kGQViDzOcg6r2bHnAQdW9HYTZAEUPcohn5vhbYhT5uu7aqbmtXeza/LF8OMg
# O/9S9VpRpW3OWFsUY+RbqhMQS90CXm7hwxzPhiYo3K2GyUxe6snGSf/ZGPkKaj6D
# po7HN/7wS5b2izni93BGbAZOX8XwNs6VFCmGYrz0mP8rlX+6Mm3WsLnVpfsJXcxs
# V6Q3aHh61mFD2v4h3iGlkTc8gfbKAMrlmKHaarcJxjAdmoN9RroQrCpYOhwsPTFK
# MY42oiPUbgNaRsI7KQH1HeuW6mHuQa6BtQN3lR0iE4P5rpqVxM7KZz1stGwe8m1P
# 5pe/WcjAAhyGdmzvyuq6B5ufHvF3AY0RR8YRoTvwAhDxpZEBNGmND4PmqfEWSsYA
# J0po/VJaoCDrhIn1PpO0tiv7VFe35p4ugg==
# SIG # End signature block
