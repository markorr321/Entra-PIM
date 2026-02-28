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
# MIIr0AYJKoZIhvcNAQcCoIIrwTCCK70CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCNHO8lfxzxCiFd
# CbARdnjm/9G1SdQg1VYYIn/+GTMOuKCCJOQwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYUMIID/KADAgECAhB6I67a
# U2mWD5HIPlz0x+M/MA0GCSqGSIb3DQEBDAUAMFcxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRp
# bWUgU3RhbXBpbmcgUm9vdCBSNDYwHhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1
# OTU5WjBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSww
# KgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNjCCAaIw
# DQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAM2Y2ENBq26CK+z2M34mNOSJjNPv
# IhKAVD7vJq+MDoGD46IiM+b83+3ecLvBhStSVjeYXIjfa3ajoW3cS3ElcJzkyZlB
# nwDEJuHlzpbN4kMH2qRBVrjrGJgSlzzUqcGQBaCxpectRGhhnOSwcjPMI3G0hedv
# 2eNmGiUbD12OeORN0ADzdpsQ4dDi6M4YhoGE9cbY11XxM2AVZn0GiOUC9+XE0wI7
# CQKfOUfigLDn7i/WeyxZ43XLj5GVo7LDBExSLnh+va8WxTlA+uBvq1KO8RSHUQLg
# zb1gbL9Ihgzxmkdp2ZWNuLc+XyEmJNbD2OIIq/fWlwBp6KNL19zpHsODLIsgZ+WZ
# 1AzCs1HEK6VWrxmnKyJJg2Lv23DlEdZlQSGdF+z+Gyn9/CRezKe7WNyxRf4e4bwU
# trYE2F5Q+05yDD68clwnweckKtxRaF0VzN/w76kOLIaFVhf5sMM/caEZLtOYqYad
# tn034ykSFaZuIBU9uCSrKRKTPJhWvXk4CllgrwIDAQABo4IBXDCCAVgwHwYDVR0j
# BBgwFoAU9ndq3T/9ARP/FqFsggIv0Ao9FCUwHQYDVR0OBBYEFF9Y7UwxeqJhQo1S
# gLqzYZcZojKbMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMBMG
# A1UdJQQMMAoGCCsGAQUFBwMIMBEGA1UdIAQKMAgwBgYEVR0gADBMBgNVHR8ERTBD
# MEGgP6A9hjtodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1l
# U3RhbXBpbmdSb290UjQ2LmNybDB8BggrBgEFBQcBAQRwMG4wRwYIKwYBBQUHMAKG
# O2h0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGlu
# Z1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNv
# bTANBgkqhkiG9w0BAQwFAAOCAgEAEtd7IK0ONVgMnoEdJVj9TC1ndK/HYiYh9lVU
# acahRoZ2W2hfiEOyQExnHk1jkvpIJzAMxmEc6ZvIyHI5UkPCbXKspioYMdbOnBWQ
# Un733qMooBfIghpR/klUqNxx6/fDXqY0hSU1OSkkSivt51UlmJElUICZYBodzD3M
# /SFjeCP59anwxs6hwj1mfvzG+b1coYGnqsSz2wSKr+nDO+Db8qNcTbJZRAiSazr7
# KyUJGo1c+MScGfG5QHV+bps8BX5Oyv9Ct36Y4Il6ajTqV2ifikkVtB3RNBUgwu/m
# SiSUice/Jp/q8BMk/gN8+0rNIE+QqU63JoVMCMPY2752LmESsRVVoypJVt8/N3qQ
# 1c6FibbcRabo3azZkcIdWGVSAdoLgAIxEKBeNh9AQO1gQrnh1TA8ldXuJzPSuALO
# z1Ujb0PCyNVkWk7hkhVHfcvBfI8NtgWQupiaAeNHe0pWSGH2opXZYKYG4Lbukg7H
# pNi/KqJhue2Keak6qH9A8CeEOB7Eob0Zf+fU+CCQaL0cJqlmnx9HCDxF+3BLbUuf
# rV64EbTI40zqegPZdA+sXCmbcZy6okx/SjwsusWRItFA3DE8MORZeFb6BmzBtqKJ
# 7l939bbKBy2jvxcJI98Va95Q5JnlKor3m0E7xpMeYRriWklUPsetMSf2NvUQa/E5
# vVyefQIwggYaMIIEAqADAgECAhBiHW0MUgGeO5B5FSCJIRwKMA0GCSqGSIb3DQEB
# DAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLTAr
# BgNVBAMTJFNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBSb290IFI0NjAeFw0y
# MTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTlaMFQxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBDQSBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIB
# gQCbK51T+jU/jmAGQ2rAz/V/9shTUxjIztNsfvxYB5UXeWUzCxEeAEZGbEN4QMgC
# sJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFigOMYzB2OKhdqfWGVoYW3haT29PST
# ahYkwmMv0b/83nbeECbiMXhSOtbam+/36F09fy1tsB8je/RV0mIk8XL/tfCK6cPu
# YHE215wzrK0h1SWHTxPbPuYkRdkP05ZwmRmTnAO5/arnY83jeNzhP06ShdnRqtZl
# V59+8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp4VqpB3MV/h53yl41aHU5pledi9lC
# BbH9JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8rNyfQJy/aOs5b4s+ac7IH60B+Ja7
# TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ1f9+YEQIQty/NQd/2yGgW+ufflcZ
# /ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh2n5HirY4jKnFH/9gRvd+QOfdRrJZ
# b1sCAwEAAaOCAWQwggFgMB8GA1UdIwQYMBaAFDLrkpr/NZZILyhAQnAgNpFcF4Xm
# MB0GA1UdDgQWBBQPKssghyi47G9IritUpimqF6TNDDAOBgNVHQ8BAf8EBAMCAYYw
# EgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzAbBgNVHSAE
# FDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9j
# cmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5j
# cmwwewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUFBzAChjpodHRwOi8vY3J0LnNlY3Rp
# Z28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RSNDYucDdjMCMGCCsG
# AQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOC
# AgEABv+C4XdjNm57oRUgmxP/BP6YdURhw1aVcdGRP4Wh60BAscjW4HL9hcpkOTz5
# jUug2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWTsyNyBBsMLHqafvIhrCymlaS98+Qp
# oBCyKppP0OcxYEdU0hpsaqBBIZOtBajjcw5+w/KeFvPYfLF/ldYpmlG+vd0xqlqd
# 099iChnyIMvY5HexjO2AmtsbpVn0OhNcWbWDRF/3sBp6fWXhz7DcML4iTAWS+MVX
# eNLj1lJziVKEoroGs9Mlizg0bUMbOalOhOfCipnx8CaLZeVme5yELg09Jlo8BMe8
# 0jO37PU8ejfkP9/uPak7VLwELKxAMcJszkyeiaerlphwoKx1uHRzNyE6bxuSKcut
# isqmKL5OTunAvtONEoteSiabkPVSZ2z76mKnzAfZxCl/3dq3dUNw4rg3sTCggkHS
# RqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGvspbOrTfOXyXvmPL6E52z1NZJ6ctu
# MFBQZH3pwWvqURR8AgQdULUvrxjUYbHHj95Ejza63zdrEcxWLDX6xWls/GDnVNue
# KjWUH3fTv1Y8Wdho698YADR7TNx8X8z2Bev6SivBBOHY+uqiirZtg0y9ShQoPzmC
# cn63Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2RwwggZLMIIEs6ADAgEC
# AhEAh4S8tN9yByR3E9jATIZw9DANBgkqhkiG9w0BAQwFADBUMQswCQYDVQQGEwJH
# QjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1
# YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MB4XDTI2MDIyNDAwMDAwMFoXDTI3MDIy
# NDIzNTk1OVowRDELMAkGA1UEBhMCVVMxDzANBgNVBAgMBkthbnNhczERMA8GA1UE
# CgwITWFyayBPcnIxETAPBgNVBAMMCE1hcmsgT3JyMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEAx9tr2sjXvlV3KjWWeg0HYTDicFwZDZv2tI//RO1C9IL7
# uShmYN0eSeyWZW/GNy7fTOlIJ6poUe4R3/ApsNsw9hpOMXc92BnyDs/UXHMYx2Yd
# OO4XI35IxfhZnZhgIj2acQ0BZ542hmYAwtz8c1Xu9xH51eTArmFWHV8angRsuFMV
# yKQOraWQs37tqOVwXeH3FQIT0mFBTbmENhgyxAGLq8nZMFM+JqVVWeRgvTFO48UZ
# f0BhgH84k2M44CcA9vVML7w4yueg6qD6D/k7Opy1OfCR1qxSXI0wZeUXodJvgisD
# RScKZJfPID6PIxxvoeem4VKkV0y3eBF+UtdQ8+NZ7qmlRl2hE6H6efWSRNW2imxe
# VSg9FgQONnJYhkyJmaio/NnLyDB6PyoCDZQaYDiMRRiycHPbYvbas0THWB2NFsgr
# 3h3QZxQfZnNB2F/ZVdNlfbGpxTK53Yhf5XT0iaEat9r82wwjlP9c/PEl1q8G53Pc
# o/ykqBk/V2PfohhuwiXBHb5zL518lCPPZmOCdIqyvkgAUzWymHSiTwm/ZNTNEaHL
# aktfBJ52G03r7F1YHSxPDJpH84RrBQwNWA8olog3uvvWTWImDuQd8PdvhOrluh11
# pvMWRn+ic6e2E7A4KQr0x4bZoL/gWBTE9tL8AuCJyjxsjiDAbJRxd3Di5Bi7pGsC
# AwEAAaOCAaYwggGiMB8GA1UdIwQYMBaAFA8qyyCHKLjsb0iuK1SmKaoXpM0MMB0G
# A1UdDgQWBBRlBYoMei+jtIKM2eL9y3kX+l6hqzAOBgNVHQ8BAf8EBAMCB4AwDAYD
# VR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzBKBgNVHSAEQzBBMDUGDCsG
# AQQBsjEBAgEDAjAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQ
# UzAIBgZngQwBBAEwSQYDVR0fBEIwQDA+oDygOoY4aHR0cDovL2NybC5zZWN0aWdv
# LmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcmwweQYIKwYBBQUH
# AQEEbTBrMEQGCCsGAQUFBzAChjhodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3Rp
# Z29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2LmNydDAjBggrBgEFBQcwAYYXaHR0cDov
# L29jc3Auc2VjdGlnby5jb20wGwYDVR0RBBQwEoEQbW9yckBvcnIzNjUudGVjaDAN
# BgkqhkiG9w0BAQwFAAOCAYEAQYDywuGVM9hgCjKW/Til/gPycxB1XL4OH7/9jV72
# /HPbBKnwXwiFlgTO+Lo4UEbZNy+WQk60u0XtrBIKUbhlapRGQPrl2OKpf9rYOyys
# g1puVTqnaxY9vevhgB4NVpHqYMi8+Kzpa2rXzXyrVdbVNIMn00ZAV6tBTr0fhMt3
# P4oxF0WYQ/GjfUa1/8O3uqeni36iMyCqP7ao9rJgCOgNvEBokRhh7fFC5YVIjMKw
# vU/7CgbkgjIBHfX4UMxU2BNvCGTR2ZA5IznmLsRI/4MEP9LMLV8DQm8wh2P1uCaG
# ANSLQ0EQIZtMEm1i03zBwDOTBLVAo7p+2Pw2q7LEOQni6LeX5AzTnRvHwcisRM3K
# pvx+H6wJnL6x7TXZ7YCHhJ4ZTuMWblXJjVKPueEQfIh04x7oVbIV8LNqVyoP9gJZ
# fkmn5IW8cwIFAzFMsNqW1URfArzJ5An9xIYCUJbzohgtE71NjqiZPI1k4Gxzsyeq
# TNaXEXnzZEfogAvEmHFMMNXGMIIGYjCCBMqgAwIBAgIRAKQpO24e3denNAiHrXpO
# tyQwDQYJKoZIhvcNAQEMBQAwVTELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3Rp
# Z28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGlu
# ZyBDQSBSMzYwHhcNMjUwMzI3MDAwMDAwWhcNMzYwMzIxMjM1OTU5WjByMQswCQYD
# VQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZb3Jrc2hpcmUxGDAWBgNVBAoTD1NlY3Rp
# Z28gTGltaXRlZDEwMC4GA1UEAxMnU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGlu
# ZyBTaWduZXIgUjM2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA04SV
# 9G6kU3jyPRBLeBIHPNyUgVNnYayfsGOyYEXrn3+SkDYTLs1crcw/ol2swE1TzB2a
# R/5JIjKNf75QBha2Ddj+4NEPKDxHEd4dEn7RTWMcTIfm492TW22I8LfH+A7Ehz0/
# safc6BbsNBzjHTt7FngNfhfJoYOrkugSaT8F0IzUh6VUwoHdYDpiln9dh0n0m545
# d5A5tJD92iFAIbKHQWGbCQNYplqpAFasHBn77OqW37P9BhOASdmjp3IijYiFdcA0
# WQIe60vzvrk0HG+iVcwVZjz+t5OcXGTcxqOAzk1frDNZ1aw8nFhGEvG0ktJQknnJ
# ZE3D40GofV7O8WzgaAnZmoUn4PCpvH36vD4XaAF2CjiPsJWiY/j2xLsJuqx3JtuI
# 4akH0MmGzlBUylhXvdNVXcjAuIEcEQKtOBR9lU4wXQpISrbOT8ux+96GzBq8Tdbh
# oFcmYaOBZKlwPP7pOp5Mzx/UMhyBA93PQhiCdPfIVOCINsUY4U23p4KJ3F1HqP3H
# 6Slw3lHACnLilGETXRg5X/Fp8G8qlG5Y+M49ZEGUp2bneRLZoyHTyynHvFISpefh
# BCV0KdRZHPcuSL5OAGWnBjAlRtHvsMBrI3AAA0Tu1oGvPa/4yeeiAyu+9y3SLC98
# gDVbySnXnkujjhIh+oaatsk/oyf5R2vcxHahajMCAwEAAaOCAY4wggGKMB8GA1Ud
# IwQYMBaAFF9Y7UwxeqJhQo1SgLqzYZcZojKbMB0GA1UdDgQWBBSIYYyhKjdkgShg
# oZsx0Iz9LALOTzAOBgNVHQ8BAf8EBAMCBsAwDAYDVR0TAQH/BAIwADAWBgNVHSUB
# Af8EDDAKBggrBgEFBQcDCDBKBgNVHSAEQzBBMDUGDCsGAQQBsjEBAgEDCDAlMCMG
# CCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZngQwBBAIwSgYD
# VR0fBEMwQTA/oD2gO4Y5aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVi
# bGljVGltZVN0YW1waW5nQ0FSMzYuY3JsMHoGCCsGAQUFBwEBBG4wbDBFBggrBgEF
# BQcwAoY5aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0
# YW1waW5nQ0FSMzYuY3J0MCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdv
# LmNvbTANBgkqhkiG9w0BAQwFAAOCAYEAAoE+pIZyUSH5ZakuPVKK4eWbzEsTRJOE
# jbIu6r7vmzXXLpJx4FyGmcqnFZoa1dzx3JrUCrdG5b//LfAxOGy9Ph9JtrYChJaV
# HrusDh9NgYwiGDOhyyJ2zRy3+kdqhwtUlLCdNjFjakTSE+hkC9F5ty1uxOoQ2Zkf
# I5WM4WXA3ZHcNHB4V42zi7Jk3ktEnkSdViVxM6rduXW0jmmiu71ZpBFZDh7Kdens
# +PQXPgMqvzodgQJEkxaION5XRCoBxAwWwiMm2thPDuZTzWp/gUFzi7izCmEt4pE3
# Kf0MOt3ccgwn4Kl2FIcQaV55nkjv1gODcHcD9+ZVjYZoyKTVWb4VqMQy/j8Q3aaY
# d/jOQ66Fhk3NWbg2tYl5jhQCuIsE55Vg4N0DUbEWvXJxtxQQaVR5xzhEI+BjJKzh
# 3TQ026JxHhr2fuJ0mV68AluFr9qshgwS5SpN5FFtaSEnAwqZv3IS+mlG50rK7W3q
# XbWwi4hmpylUfygtYLEdLQukNEX1jiOKMIIGgjCCBGqgAwIBAgIQNsKwvXwbOuej
# s902y8l1aDANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Ck5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUg
# VVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlm
# aWNhdGlvbiBBdXRob3JpdHkwHhcNMjEwMzIyMDAwMDAwWhcNMzgwMTE4MjM1OTU5
# WjBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS4wLAYD
# VQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2MIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAiJ3YuUVnnR3d6LkmgZpUVMB8SQWb
# zFoVD9mUEES0QUCBdxSZqdTkdizICFNeINCSJS+lV1ipnW5ihkQyC0cRLWXUJzod
# qpnMRs46npiJPHrfLBOifjfhpdXJ2aHHsPHggGsCi7uE0awqKggE/LkYw3sqaBia
# 67h/3awoqNvGqiFRJ+OTWYmUCO2GAXsePHi+/JUNAax3kpqstbl3vcTdOGhtKShv
# ZIvjwulRH87rbukNyHGWX5tNK/WABKf+Gnoi4cmisS7oSimgHUI0Wn/4elNd40BF
# dSZ1EwpuddZ+Wr7+Dfo0lcHflm/FDDrOJ3rWqauUP8hsokDoI7D/yUVI9DAE/WK3
# Jl3C4LKwIpn1mNzMyptRwsXKrop06m7NUNHdlTDEMovXAIDGAvYynPt5lutv8lZe
# I5w3MOlCybAZDpK3Dy1MKo+6aEtE9vtiTMzz/o2dYfdP0KWZwZIXbYsTIlg1YIet
# Cpi5s14qiXOpRsKqFKqav9R1R5vj3NgevsAsvxsAnI8Oa5s2oy25qhsoBIGo/zi6
# GpxFj+mOdh35Xn91y72J4RGOJEoqzEIbW3q0b2iPuWLA911cRxgY5SJYubvjay3n
# SMbBPPFsyl6mY4/WYucmyS9lo3l7jk27MAe145GWxK4O3m3gEFEIkv7kRmefDR7O
# e2T1HxAnICQvr9sCAwEAAaOCARYwggESMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh
# 2JvAnfKyA2bLMB0GA1UdDgQWBBT2d2rdP/0BE/8WoWyCAi/QCj0UJTAOBgNVHQ8B
# Af8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUEDDAKBggrBgEFBQcDCDAR
# BgNVHSAECjAIMAYGBFUdIAAwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51
# c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHku
# Y3JsMDUGCCsGAQUFBwEBBCkwJzAlBggrBgEFBQcwAYYZaHR0cDovL29jc3AudXNl
# cnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEADr5lQe1oRLjlocXUEYfktzsl
# jOt+2sgXke3Y8UPEooU5y39rAARaAdAxUeiX1ktLJ3+lgxtoLQhn5cFb3GF2SSZR
# X8ptQ6IvuD3wz/LNHKpQ5nX8hjsDLRhsyeIiJsms9yAWnvdYOdEMq1W61KE9JlBk
# B20XBee6JaXx4UBErc+YuoSb1SxVf7nkNtUjPfcxuFtrQdRMRi/fInV/AobE8Gw/
# 8yBMQKKaHt5eia8ybT8Y/Ffa6HAJyz9gvEOcF1VWXG8OMeM7Vy7Bs6mSIkYeYtdd
# U1ux1dQLbEGur18ut97wgGwDiGinCwKPyFO7ApcmVJOtlw9FVJxw/mL1TbyBns4z
# OgkaXFnnfzg4qbSvnrwyj1NiurMp4pmAWjR+Pb/SIduPnmFzbSN/G8reZCL4fvGl
# vPFk4Uab/JVCSmj59+/mB2Gn6G/UYOy8k60mKcmaAZsEVkhOFuoj4we8CYyaR9vd
# 9PGZKSinaZIkvVjbH/3nlLb0a7SBIkiRzfPfS9T+JesylbHa1LtRV9U/7m0q7Ma2
# CQ/t392ioOssXW7oKLdOmMBl14suVFBmbzrt5V5cQPnwtd3UOTpS9oCG+ZZheiIv
# PgkDmA8FzPsnfXW5qHELB43ET7HHFHeRPRYrMBKjkb8/IN7Po0d0hQoF4TeMM+zY
# AJzoKQnVKOLg8pZVPT8xggZCMIIGPgIBATBpMFQxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBDQSBSMzYCEQCHhLy033IHJHcT2MBMhnD0MA0GCWCGSAFlAwQC
# AQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZI
# hvcNAQkEMSIEIPbcBBfwCWznctWAqke00+2WCcr8dELeKmv6gAJBdCxJMA0GCSqG
# SIb3DQEBAQUABIICAL1ah0k/Nai9v5ygMF79Tat6fuY+m8SWd96jqc4xR7SHjyJQ
# fluz+AzSyp54VB4inIvcAlZZa/FPMNH992IQqVTzkg6JTiJa6l9ZQzCbJ4j3j7II
# nGvX2kHQN7v7QU1FACXKegXsStlUoVlJAS6/ESseCCmvAm5NJ5MrJnV9+tca45D8
# g/f6H4RoK/Fda1E1I4xB+A2nk2LETphvidyeal0YC0N9MmqwPxXuWyIuG5kP3kSn
# RNJ/kOEzq5z3jiJZISdHAI3DoMzB5XaQZBWIPM5yDqvZsecBB1b0dhNkARQ9yiGf
# m+FtiFPm67tqpua1d7Nr8sXw4yA7/1L1WlGlbc5YWxRj5FuqExBL3QJebuHDHM+G
# JijcrYbJTF7qycZJ/9kY+QpqPoOmjsc3/vBLlvaLOeL3cEZsBk5fxfA2zpUUKYZi
# vPSY/yuVf7oybdawudWl+wldzGxXpDdoeHrWYUPa/iHeIaWRNzyB9soAyuWYodpq
# twnGMB2ag31GuhCsKlg6HCw9MUoxjjaiI9RuA1pGwjspAfUd65bqYe5BroG1A3eV
# HSITg/mumpXEzspnPWy0bB7ybU/ml79ZyMACHIZ2bO/K6roHm58e8XcBjRFHxhGh
# O/ACEPGlkQE0aY0Pg+ap8RZKxgAnSmj9UlqgIOuEifU+k7S2K/tUV7fmni6CoYID
# IzCCAx8GCSqGSIb3DQEJBjGCAxAwggMMAgEBMGowVTELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMg
# VGltZSBTdGFtcGluZyBDQSBSMzYCEQCkKTtuHt3XpzQIh616TrckMA0GCWCGSAFl
# AwQCAgUAoHkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUx
# DxcNMjYwMjI4MTAzOTA5WjA/BgkqhkiG9w0BCQQxMgQwYRmcBKomgk72EA6a3C+7
# T3ao4LBuntueH8fpyW5gGBzykr82TyM8QA2kf/Wyfn6SMA0GCSqGSIb3DQEBAQUA
# BIICAHwRw08YEvhErXDy6tB9oXwO8mHGc9lFkqiPH9d7Eg8ZJJIS92yvrwK1VU7n
# NOEvIzgfYuESRNlLAIbVj0H9Nxj5Cuof7VCNRMTOSlJHrKZdOgK2VxTL4yYAU5Il
# I7S/6Gqvzg6H6s4i/vXWsEgO874zYGB7Qo3GtGVpT5u0UWxe0edx7++0muLwmSCH
# KDceVCu6YSFlxqmssJlEZxIErIZ/zbYp3n8uuFLqYHDB6XqnU1mTHBAeD3NBhjLV
# NKP2gseylvM3HD8EMcWF157OYsF6nGE5fyyBN/wUaHhv8jlBdDcVx3F8PDKIVdj3
# XZbuyj3wd8HyP8ov+G1Tdvca8YBu8BEDCyXoQklKmo+VFR4yEpGx2/N1xBHI8AKZ
# xnhIa2fkgEcRKUZdFI2z4ZJwld01QcMHi6otKi09zCFryH1qQ5/H40TiP3P9Jm6W
# x26iYoCaGl6//+uMup/7N1XRGxTc01MxYKEhYzZPsc4mpJEm8YiCP7736p87fInS
# f9fO1aq3UETA6mhMhwAXRSmlfaQt14z6o3UuhSBhbSq/zRQIVnnxMJUlYvAuZr9E
# WN0TMUa1oNdpfX0P5t3rw1KY4L7p5aCCtOKsZS6R20ZRDlKhoWh5zM874RAgEP8f
# P/qLzbHpKaTdYBEyCWOImlAzshJpfb9OCx7pdSjnfEQ+TeCy
# SIG # End signature block
