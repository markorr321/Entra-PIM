@{
    # Module manifest for Entra-PIM
    # Generated for PSResourceGet / GitHub Releases distribution

    # Script module or binary module file associated with this manifest
    RootModule = 'Entra-PIM.psm1'

    # Version number of this module (SemVer format for PSResourceGet)
    ModuleVersion = '2.3.2'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'markorr321'

    # Company or vendor of this module
    CompanyName = 'Orr365'

    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'PowerShell module for managing Microsoft Entra PIM (Privileged Identity Management) role activations and deactivations through an interactive console experience. Supports Entra ID roles, Azure Resource roles, and Groups PIM with browser-based authentication. Features automatic step-up MFA handling, one-command activation/deactivation, and auto-installation of dependencies. Cross-platform compatible with Windows, macOS, and Linux. Just run Start-EntraPIM - works out of the box with no configuration, or bring your own app registration for full control.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()  # Dependencies checked at runtime instead

    # Functions to export from this module
    FunctionsToExport = @('Start-EntraPIM', 'Configure-EntraPIM', 'Clear-EntraPIMConfig', 'Get-EntraPIMHelp')

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for discoverability in online galleries
            Tags = @('Entra', 'PIM', 'Azure', 'Identity', 'Governance', 'MicrosoftGraph', 'Privileged', 'RoleManagement', 'AzureResources', 'Groups', 'CrossPlatform', 'macOS')

            # A URL to the license for this module
            LicenseUri = 'https://github.com/markorr321/Entra-PIM/blob/main/LICENSE'

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/markorr321/Entra-PIM'

            # A URL to an icon representing this module
            IconUri = 'https://raw.githubusercontent.com/markorr321/Entra-PIM/main/icon.png'

            # ReleaseNotes of this module
            ReleaseNotes = @'
## 2.3.2
- Script signature for enhanced security
- Updated demo video
- General maintenance and stability improvements

## 2.3.1
- Added Groups PIM support - activate/deactivate Entra group memberships (member and owner roles)
- Policy duration display shows max allowed time for each group in selection menu
- Activation preview when requested duration exceeds policy limits
- Smart duration capping - each group activates for its individual policy maximum if exceeded
- Fixed Ctrl+A select all in Azure role menus
- Added branded HTML authentication success/error pages
- Updated help documentation (Get-EntraPIMHelp) with Groups PIM permissions
- Updated README with Groups PIM features and permissions

## 2.3.0
- Added back navigation to all menus - select "← Back" to return to the previous screen
- Live countdown timers on deactivation role selection (expiration updates every second)
- Back from Azure action menu returns to subscription selection (not workflow selector)
- Step-back through activation form: ESC goes reason → duration → role selection
- Back button on 5-minute deactivation countdown screen (any key to go back)

## 2.2.9
- Added step-up authentication support for Azure PIM roles
- Handles Conditional Access claims challenges (C1/C4) automatically when activating Azure roles
- Seamless re-authentication and retry on claims challenge, matching Entra PIM behavior

## 2.2.8
- Fixed Azure PIM group-based role activation (uses user OID from JWT token)
- Consistent activation/deactivation UI messages between Entra and Azure workflows
- Simplified exit handling (disconnect only, no terminal close attempts)

## 2.2.4
- Development version for testing update notifications

## 2.2.3
- Fixed update notification version detection - now properly extracts version from PowerShell Gallery redirect headers
- Update notifications now work correctly for all users

## 2.2.2
- Test release for update notification functionality

## 2.2.1
- Interactive update prompt - users can now update immediately when prompted (Y/N/Enter)
- Auto-update on confirmation with automatic module reload
- Improved user experience with "Press Enter to Exit" prompts (no colon)

## 2.2.0
- Added automatic update notifications - checks PowerShell Gallery once per 24 hours
- Inline red notification when newer version is available
- Cached version checks to minimize network calls
- 5-second timeout for non-blocking updates
- Can be disabled via ENTRAPIM_DISABLE_UPDATE_CHECK environment variable

## 2.1.0
- Added Configure-EntraPIM command for persistent configuration via environment variables
- Added Clear-EntraPIMConfig command to remove saved configuration
- Added Get-EntraPIMHelp command for comprehensive command reference
- Added visual confirmation of which app registration is being used during authentication
- Fixed Windows terminal exit behavior for Ctrl+Q in Entra workflow
- Fixed MSAL assembly conflict when multiple Microsoft modules are loaded
- macOS: Automatic PowerShell profile integration for persistent configuration

## 2.0.9
- Bug fix: Module wrapper now properly exposes ClientId and TenantId parameters

## 2.0.8
- Added ClientId and TenantId parameters for custom app registration support
- Switched to least-privilege Graph permissions for better security
- Fixed macOS terminal exit to avoid session save messages

## 2.0.7
- Additional macOS compatibility improvements

## 2.0.6
- Fixed macOS auto-exit issue - clear input buffer after setting TreatControlCAsInput

## 2.0.5
- Fixed Ctrl+C not working on macOS - now properly captures as keyboard input
- Added TreatControlCAsInput for macOS/Linux platforms
- Ctrl+C now works as quit shortcut alongside Ctrl+Q on all platforms

## 2.0.4
- Fixed exit behavior - no longer kills parent apps like VS Code or Windows Terminal
- Only terminates parent PowerShell processes when running nested

## 2.0.3
- Performance optimization: REST API calls with $select for faster role loading
- Fixed deactivation workflow - includes all required fields (PrincipalId, DirectoryScopeId)
- Fixed terminal exit behavior - properly closes terminal on exit
- Simplified input prompts with inline cursor positioning
- Azure PIM: Better subscription discovery via PIM eligible roles API

## 2.0.2
- Handle Ctrl+C gracefully with proper disconnect from Graph/Azure

## 2.0.1
- Fix activation status detection for roles with pending requests

## 2.0.0
- **MAJOR**: Added Azure Resource role support alongside Entra ID roles
- Workflow selector to choose between Entra ID and Azure Resource PIM
- Cross-platform support for Windows and macOS
- Browser-based authentication with ForceLogin prompt
- Dynamic keyboard shortcuts based on platform
- Silent prerequisite checking (only shows output when modules need installing)

## 1.6.0
- Added step-up authentication support for PIM role activations
- Handles MFA/claims challenges automatically when activating privileged roles

## 1.5.0
- Added auto-installation of required modules (Az.Accounts, Microsoft.Graph)
- Script now automatically installs missing dependencies on first run

## 1.4.0
- Switched to WAM (Windows Account Manager) authentication for native SSO
- Removed app registration dependency - uses Microsoft public client ID
- Renamed script to Entra-PIM.ps1
- Code cleanup and optimizations

## 1.3.2
- Bug fixes

## 1.3.1
- Fixed project URLs in manifest

## 1.3.0
- Removed Microsoft.Graph.Users dependency
- Fixed module loading issues
- Improved error handling for module imports

## 1.2.0
- Performance optimizations
- Bug fixes

## 1.0.0
- Initial release
- Browser-based authentication with PKCE
- Role activation and deactivation workflows
- Interactive TUI for role selection
- Caching for optimized API calls
'@

            # Prerelease string of this module
            Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            RequireLicenseAcceptance = $false
        }
    }
}

# SIG # Begin signature block
# MIIrqwYJKoZIhvcNAQcCoIIrnDCCK5gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUUfirBEPv+wRQ3Fe3kNZ0A3cB
# doKggiTkMIIFbzCCBFegAwIBAgIQSPyTtGBVlI02p8mKidaUFjANBgkqhkiG9w0B
# AQwFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEh
# MB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTIxMDUyNTAwMDAw
# MFoXDTI4MTIzMTIzNTk1OVowVjELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3Rp
# Z28gTGltaXRlZDEtMCsGA1UEAxMkU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5n
# IFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjeeUEiIE
# JHQu/xYjApKKtq42haxH1CORKz7cfeIxoFFvrISR41KKteKW3tCHYySJiv/vEpM7
# fbu2ir29BX8nm2tl06UMabG8STma8W1uquSggyfamg0rUOlLW7O4ZDakfko9qXGr
# YbNzszwLDO/bM1flvjQ345cbXf0fEj2CA3bm+z9m0pQxafptszSswXp43JJQ8mTH
# qi0Eq8Nq6uAvp6fcbtfo/9ohq0C/ue4NnsbZnpnvxt4fqQx2sycgoda6/YDnAdLv
# 64IplXCN/7sVz/7RDzaiLk8ykHRGa0c1E3cFM09jLrgt4b9lpwRrGNhx+swI8m2J
# mRCxrds+LOSqGLDGBwF1Z95t6WNjHjZ/aYm+qkU+blpfj6Fby50whjDoA7NAxg0P
# OM1nqFOI+rgwZfpvx+cdsYN0aT6sxGg7seZnM5q2COCABUhA7vaCZEao9XOwBpXy
# bGWfv1VbHJxXGsd4RnxwqpQbghesh+m2yQ6BHEDWFhcp/FycGCvqRfXvvdVnTyhe
# Be6QTHrnxvTQ/PrNPjJGEyA2igTqt6oHRpwNkzoJZplYXCmjuQymMDg80EY2NXyc
# uu7D1fkKdvp+BRtAypI16dV60bV/AK6pkKrFfwGcELEW/MxuGNxvYv6mUKe4e7id
# FT/+IAx1yCJaE5UZkADpGtXChvHjjuxf9OUCAwEAAaOCARIwggEOMB8GA1UdIwQY
# MBaAFKARCiM+lvEH7OKvKe+CpX/QMKS0MB0GA1UdDgQWBBQy65Ka/zWWSC8oQEJw
# IDaRXBeF5jAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUE
# DDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEMGA1Ud
# HwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0FBQUNlcnRpZmlj
# YXRlU2VydmljZXMuY3JsMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuY29tb2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4IBAQASv6Hvi3Sa
# mES4aUa1qyQKDKSKZ7g6gb9Fin1SB6iNH04hhTmja14tIIa/ELiueTtTzbT72ES+
# BtlcY2fUQBaHRIZyKtYyFfUSg8L54V0RQGf2QidyxSPiAjgaTCDi2wH3zUZPJqJ8
# ZsBRNraJAlTH/Fj7bADu/pimLpWhDFMpH2/YGaZPnvesCepdgsaLr4CnvYFIUoQx
# 2jLsFeSmTD1sOXPUC4U5IOCFGmjhp0g4qdE2JXfBjRkWxYhMZn0vY86Y6GnfrDyo
# XZ3JHFuu2PMvdM+4fvbXg50RlmKarkUT2n/cR/vfw1Kf5gZV6Z2M8jpiUbzsJA8p
# 1FiAhORFe1rYMIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c9MfjPzANBgkqhkiG
# 9w0BAQwFADBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2
# MB4XDTIxMDMyMjAwMDAwMFoXDTM2MDMyMTIzNTk1OVowVTELMAkGA1UEBhMCR0Ix
# GDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJs
# aWMgVGltZSBTdGFtcGluZyBDQSBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAw
# ggGKAoIBgQDNmNhDQatugivs9jN+JjTkiYzT7yISgFQ+7yavjA6Bg+OiIjPm/N/t
# 3nC7wYUrUlY3mFyI32t2o6Ft3EtxJXCc5MmZQZ8AxCbh5c6WzeJDB9qkQVa46xiY
# Epc81KnBkAWgsaXnLURoYZzksHIzzCNxtIXnb9njZholGw9djnjkTdAA83abEOHQ
# 4ujOGIaBhPXG2NdV8TNgFWZ9BojlAvflxNMCOwkCnzlH4oCw5+4v1nssWeN1y4+R
# laOywwRMUi54fr2vFsU5QPrgb6tSjvEUh1EC4M29YGy/SIYM8ZpHadmVjbi3Pl8h
# JiTWw9jiCKv31pcAaeijS9fc6R7DgyyLIGflmdQMwrNRxCulVq8ZpysiSYNi79tw
# 5RHWZUEhnRfs/hsp/fwkXsynu1jcsUX+HuG8FLa2BNheUPtOcgw+vHJcJ8HnJCrc
# UWhdFczf8O+pDiyGhVYX+bDDP3GhGS7TmKmGnbZ9N+MpEhWmbiAVPbgkqykSkzyY
# Vr15OApZYK8CAwEAAaOCAVwwggFYMB8GA1UdIwQYMBaAFPZ3at0//QET/xahbIIC
# L9AKPRQlMB0GA1UdDgQWBBRfWO1MMXqiYUKNUoC6s2GXGaIymzAOBgNVHQ8BAf8E
# BAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDCDAR
# BgNVHSAECjAIMAYGBFUdIAAwTAYDVR0fBEUwQzBBoD+gPYY7aHR0cDovL2NybC5z
# ZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5nUm9vdFI0Ni5jcmww
# fAYIKwYBBQUHAQEEcDBuMEcGCCsGAQUFBzAChjtodHRwOi8vY3J0LnNlY3RpZ28u
# Y29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdSb290UjQ2LnA3YzAjBggrBgEF
# BQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQADggIB
# ABLXeyCtDjVYDJ6BHSVY/UwtZ3Svx2ImIfZVVGnGoUaGdltoX4hDskBMZx5NY5L6
# SCcwDMZhHOmbyMhyOVJDwm1yrKYqGDHWzpwVkFJ+996jKKAXyIIaUf5JVKjccev3
# w16mNIUlNTkpJEor7edVJZiRJVCAmWAaHcw9zP0hY3gj+fWp8MbOocI9Zn78xvm9
# XKGBp6rEs9sEiq/pwzvg2/KjXE2yWUQIkms6+yslCRqNXPjEnBnxuUB1fm6bPAV+
# Tsr/Qrd+mOCJemo06ldon4pJFbQd0TQVIMLv5koklInHvyaf6vATJP4DfPtKzSBP
# kKlOtyaFTAjD2Nu+di5hErEVVaMqSVbfPzd6kNXOhYm23EWm6N2s2ZHCHVhlUgHa
# C4ACMRCgXjYfQEDtYEK54dUwPJXV7icz0rgCzs9VI29DwsjVZFpO4ZIVR33LwXyP
# DbYFkLqYmgHjR3tKVkhh9qKV2WCmBuC27pIOx6TYvyqiYbntinmpOqh/QPAnhDge
# xKG9GX/n1PggkGi9HCapZp8fRwg8RftwS21Ln61euBG0yONM6noD2XQPrFwpm3Gc
# uqJMf0o8LLrFkSLRQNwxPDDkWXhW+gZswbaiie5fd/W2ygcto78XCSPfFWveUOSZ
# 5SqK95tBO8aTHmEa4lpJVD7HrTEn9jb1EGvxOb1cnn0CMIIGGjCCBAKgAwIBAgIQ
# Yh1tDFIBnjuQeRUgiSEcCjANBgkqhkiG9w0BAQwFADBWMQswCQYDVQQGEwJHQjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdvIFB1Ymxp
# YyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwHhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIx
# MjM1OTU5WjBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MIIB
# ojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAmyudU/o1P45gBkNqwM/1f/bI
# U1MYyM7TbH78WAeVF3llMwsRHgBGRmxDeEDIArCS2VCoVk4Y/8j6stIkmYV5Gej4
# NgNjVQ4BYoDjGMwdjioXan1hlaGFt4Wk9vT0k2oWJMJjL9G//N523hAm4jF4UjrW
# 2pvv9+hdPX8tbbAfI3v0VdJiJPFy/7XwiunD7mBxNtecM6ytIdUlh08T2z7mJEXZ
# D9OWcJkZk5wDuf2q52PN43jc4T9OkoXZ0arWZVeffvMr/iiIROSCzKoDmWABDRzV
# /UiQ5vqsaeFaqQdzFf4ed8peNWh1OaZXnYvZQgWx/SXiJDRSAolRzZEZquE6cbcH
# 747FHncs/Kzcn0Ccv2jrOW+LPmnOyB+tAfiWu01TPhCr9VrkxsHC5qFNxaThTG5j
# 4/Kc+ODD2dX/fmBECELcvzUHf9shoFvrn35XGf2RPaNTO2uSZ6n9otv7jElspkfK
# 9qEATHZcodp+R4q2OIypxR//YEb3fkDn3UayWW9bAgMBAAGjggFkMIIBYDAfBgNV
# HSMEGDAWgBQy65Ka/zWWSC8oQEJwIDaRXBeF5jAdBgNVHQ4EFgQUDyrLIIcouOxv
# SK4rVKYpqhekzQwwDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAw
# EwYDVR0lBAwwCgYIKwYBBQUHAwMwGwYDVR0gBBQwEjAGBgRVHSAAMAgGBmeBDAEE
# ATBLBgNVHR8ERDBCMECgPqA8hjpodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3Rp
# Z29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RSNDYuY3JsMHsGCCsGAQUFBwEBBG8wbTBG
# BggrBgEFBQcwAoY6aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGlj
# Q29kZVNpZ25pbmdSb290UjQ2LnA3YzAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Au
# c2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQADggIBAAb/guF3YzZue6EVIJsT/wT+
# mHVEYcNWlXHRkT+FoetAQLHI1uBy/YXKZDk8+Y1LoNqHrp22AKMGxQtgCivnDHFy
# AQ9GXTmlk7MjcgQbDCx6mn7yIawsppWkvfPkKaAQsiqaT9DnMWBHVNIabGqgQSGT
# rQWo43MOfsPynhbz2Hyxf5XWKZpRvr3dMapandPfYgoZ8iDL2OR3sYztgJrbG6VZ
# 9DoTXFm1g0Rf97Aaen1l4c+w3DC+IkwFkvjFV3jS49ZSc4lShKK6BrPTJYs4NG1D
# GzmpToTnwoqZ8fAmi2XlZnuchC4NPSZaPATHvNIzt+z1PHo35D/f7j2pO1S8BCys
# QDHCbM5Mnomnq5aYcKCsdbh0czchOm8bkinLrYrKpii+Tk7pwL7TjRKLXkomm5D1
# Umds++pip8wH2cQpf93at3VDcOK4N7EwoIJB0kak6pSzEu4I64U6gZs7tS/dGNSl
# jf2OSSnRr7KWzq03zl8l75jy+hOds9TWSenLbjBQUGR96cFr6lEUfAIEHVC1L68Y
# 1GGxx4/eRI82ut83axHMViw1+sVpbPxg51Tbnio1lB93079WPFnYaOvfGAA0e0zc
# fF/M9gXr+korwQTh2Prqooq2bYNMvUoUKD85gnJ+t0smrWrb8dee2CvYZXD5laGt
# aAxOfy/VKNmwuWuAh9kcMIIGSzCCBLOgAwIBAgIRAIeEvLTfcgckdxPYwEyGcPQw
# DQYJKoZIhvcNAQEMBQAwVDELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28g
# TGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5nIENB
# IFIzNjAeFw0yNjAyMjQwMDAwMDBaFw0yNzAyMjQyMzU5NTlaMEQxCzAJBgNVBAYT
# AlVTMQ8wDQYDVQQIDAZLYW5zYXMxETAPBgNVBAoMCE1hcmsgT3JyMREwDwYDVQQD
# DAhNYXJrIE9ycjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMfba9rI
# 175Vdyo1lnoNB2Ew4nBcGQ2b9rSP/0TtQvSC+7koZmDdHknslmVvxjcu30zpSCeq
# aFHuEd/wKbDbMPYaTjF3PdgZ8g7P1FxzGMdmHTjuFyN+SMX4WZ2YYCI9mnENAWee
# NoZmAMLc/HNV7vcR+dXkwK5hVh1fGp4EbLhTFcikDq2lkLN+7ajlcF3h9xUCE9Jh
# QU25hDYYMsQBi6vJ2TBTPialVVnkYL0xTuPFGX9AYYB/OJNjOOAnAPb1TC+8OMrn
# oOqg+g/5OzqctTnwkdasUlyNMGXlF6HSb4IrA0UnCmSXzyA+jyMcb6HnpuFSpFdM
# t3gRflLXUPPjWe6ppUZdoROh+nn1kkTVtopsXlUoPRYEDjZyWIZMiZmoqPzZy8gw
# ej8qAg2UGmA4jEUYsnBz22L22rNEx1gdjRbIK94d0GcUH2ZzQdhf2VXTZX2xqcUy
# ud2IX+V09ImhGrfa/NsMI5T/XPzxJdavBudz3KP8pKgZP1dj36IYbsIlwR2+cy+d
# fJQjz2ZjgnSKsr5IAFM1sph0ok8Jv2TUzRGhy2pLXwSedhtN6+xdWB0sTwyaR/OE
# awUMDVgPKJaIN7r71k1iJg7kHfD3b4Tq5boddabzFkZ/onOnthOwOCkK9MeG2aC/
# 4FgUxPbS/ALgico8bI4gwGyUcXdw4uQYu6RrAgMBAAGjggGmMIIBojAfBgNVHSME
# GDAWgBQPKssghyi47G9IritUpimqF6TNDDAdBgNVHQ4EFgQUZQWKDHovo7SCjNni
# /ct5F/peoaswDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAww
# CgYIKwYBBQUHAwMwSgYDVR0gBEMwQTA1BgwrBgEEAbIxAQIBAwIwJTAjBggrBgEF
# BQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQBMEkGA1UdHwRC
# MEAwPqA8oDqGOGh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0Nv
# ZGVTaWduaW5nQ0FSMzYuY3JsMHkGCCsGAQUFBwEBBG0wazBEBggrBgEFBQcwAoY4
# aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdD
# QVIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMBsG
# A1UdEQQUMBKBEG1vcnJAb3JyMzY1LnRlY2gwDQYJKoZIhvcNAQEMBQADggGBAEGA
# 8sLhlTPYYAoylv04pf4D8nMQdVy+Dh+//Y1e9vxz2wSp8F8IhZYEzvi6OFBG2Tcv
# lkJOtLtF7awSClG4ZWqURkD65djiqX/a2DssrINablU6p2sWPb3r4YAeDVaR6mDI
# vPis6Wtq1818q1XW1TSDJ9NGQFerQU69H4TLdz+KMRdFmEPxo31Gtf/Dt7qnp4t+
# ojMgqj+2qPayYAjoDbxAaJEYYe3xQuWFSIzCsL1P+woG5IIyAR31+FDMVNgTbwhk
# 0dmQOSM55i7ESP+DBD/SzC1fA0JvMIdj9bgmhgDUi0NBECGbTBJtYtN8wcAzkwS1
# QKO6ftj8NquyxDkJ4ui3l+QM050bx8HIrETNyqb8fh+sCZy+se012e2Ah4SeGU7j
# Fm5VyY1Sj7nhEHyIdOMe6FWyFfCzalcqD/YCWX5Jp+SFvHMCBQMxTLDaltVEXwK8
# yeQJ/cSGAlCW86IYLRO9TY6omTyNZOBsc7MnqkzWlxF582RH6IALxJhxTDDVxjCC
# BmIwggTKoAMCAQICEQCkKTtuHt3XpzQIh616TrckMA0GCSqGSIb3DQEBDAUAMFUx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMT
# I1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgQ0EgUjM2MB4XDTI1MDMyNzAw
# MDAwMFoXDTM2MDMyMTIzNTk1OVowcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldl
# c3QgWW9ya3NoaXJlMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMT
# J1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzNjCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBANOElfRupFN48j0QS3gSBzzclIFTZ2Gs
# n7BjsmBF659/kpA2Ey7NXK3MP6JdrMBNU8wdmkf+SSIyjX++UAYWtg3Y/uDRDyg8
# RxHeHRJ+0U1jHEyH5uPdk1ttiPC3x/gOxIc9P7Gn3OgW7DQc4x07exZ4DX4XyaGD
# q5LoEmk/BdCM1IelVMKB3WA6YpZ/XYdJ9JueOXeQObSQ/dohQCGyh0FhmwkDWKZa
# qQBWrBwZ++zqlt+z/QYTgEnZo6dyIo2IhXXANFkCHutL8765NBxvolXMFWY8/reT
# nFxk3MajgM5NX6wzWdWsPJxYRhLxtJLSUJJ5yWRNw+NBqH1ezvFs4GgJ2ZqFJ+Dw
# qbx9+rw+F2gBdgo4j7CVomP49sS7CbqsdybbiOGpB9DJhs5QVMpYV73TVV3IwLiB
# HBECrTgUfZVOMF0KSEq2zk/LsfvehswavE3W4aBXJmGjgWSpcDz+6TqeTM8f1DIc
# gQPdz0IYgnT3yFTgiDbFGOFNt6eCidxdR6j9x+kpcN5RwApy4pRhE10YOV/xafBv
# KpRuWPjOPWRBlKdm53kS2aMh08spx7xSEqXn4QQldCnUWRz3Lki+TgBlpwYwJUbR
# 77DAayNwAANE7taBrz2v+MnnogMrvvct0iwvfIA1W8kp155Lo44SIfqGmrbJP6Mn
# +Udr3MR2oWozAgMBAAGjggGOMIIBijAfBgNVHSMEGDAWgBRfWO1MMXqiYUKNUoC6
# s2GXGaIymzAdBgNVHQ4EFgQUiGGMoSo3ZIEoYKGbMdCM/SwCzk8wDgYDVR0PAQH/
# BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwSgYD
# VR0gBEMwQTA1BgwrBgEEAbIxAQIBAwgwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9z
# ZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQCMEoGA1UdHwRDMEEwP6A9oDuGOWh0dHA6
# Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ0NBUjM2
# LmNybDB6BggrBgEFBQcBAQRuMGwwRQYIKwYBBQUHMAKGOWh0dHA6Ly9jcnQuc2Vj
# dGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ0NBUjM2LmNydDAjBggr
# BgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQAD
# ggGBAAKBPqSGclEh+WWpLj1SiuHlm8xLE0SThI2yLuq+75s11y6SceBchpnKpxWa
# GtXc8dya1Aq3RuW//y3wMThsvT4fSba2AoSWlR67rA4fTYGMIhgzocsids0ct/pH
# aocLVJSwnTYxY2pE0hPoZAvRebctbsTqENmZHyOVjOFlwN2R3DRweFeNs4uyZN5L
# RJ5EnVYlcTOq3bl1tI5poru9WaQRWQ4eynXp7Pj0Fz4DKr86HYECRJMWiDjeV0Qq
# AcQMFsIjJtrYTw7mU81qf4FBc4u4swphLeKRNyn9DDrd3HIMJ+CpdhSHEGleeZ5I
# 79YDg3B3A/fmVY2GaMik1Vm+FajEMv4/EN2mmHf4zkOuhYZNzVm4NrWJeY4UAriL
# BOeVYODdA1GxFr1ycbcUEGlUecc4RCPgYySs4d00NNuicR4a9n7idJlevAJbha/a
# rIYMEuUqTeRRbWkhJwMKmb9yEvppRudKyu1t6l21sIuIZqcpVH8oLWCxHS0LpDRF
# 9Y4jijCCBoIwggRqoAMCAQICEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEM
# BQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQH
# EwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4w
# LAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4X
# DTIxMDMyMjAwMDAwMFoXDTM4MDExODIzNTk1OVowVzELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMg
# VGltZSBTdGFtcGluZyBSb290IFI0NjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
# AgoCggIBAIid2LlFZ50d3ei5JoGaVFTAfEkFm8xaFQ/ZlBBEtEFAgXcUmanU5HYs
# yAhTXiDQkiUvpVdYqZ1uYoZEMgtHES1l1Cc6HaqZzEbOOp6YiTx63ywTon434aXV
# ydmhx7Dx4IBrAou7hNGsKioIBPy5GMN7KmgYmuu4f92sKKjbxqohUSfjk1mJlAjt
# hgF7Hjx4vvyVDQGsd5KarLW5d73E3ThobSkob2SL48LpUR/O627pDchxll+bTSv1
# gASn/hp6IuHJorEu6EopoB1CNFp/+HpTXeNARXUmdRMKbnXWflq+/g36NJXB35Zv
# xQw6zid61qmrlD/IbKJA6COw/8lFSPQwBP1ityZdwuCysCKZ9ZjczMqbUcLFyq6K
# dOpuzVDR3ZUwxDKL1wCAxgL2Mpz7eZbrb/JWXiOcNzDpQsmwGQ6Stw8tTCqPumhL
# RPb7YkzM8/6NnWH3T9ClmcGSF22LEyJYNWCHrQqYubNeKolzqUbCqhSqmr/UdUeb
# 49zYHr7ALL8bAJyPDmubNqMtuaobKASBqP84uhqcRY/pjnYd+V5/dcu9ieERjiRK
# KsxCG1t6tG9oj7liwPddXEcYGOUiWLm742st50jGwTzxbMpepmOP1mLnJskvZaN5
# e45NuzAHteORlsSuDt5t4BBRCJL+5EZnnw0ezntk9R8QJyAkL6/bAgMBAAGjggEW
# MIIBEjAfBgNVHSMEGDAWgBRTeb9aqitKz1SA4dibwJ3ysgNmyzAdBgNVHQ4EFgQU
# 9ndq3T/9ARP/FqFsggIv0Ao9FCUwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQF
# MAMBAf8wEwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRVHSAAMFAG
# A1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9VU0VSVHJ1
# c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDA1BggrBgEFBQcBAQQpMCcw
# JQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcN
# AQEMBQADggIBAA6+ZUHtaES45aHF1BGH5Lc7JYzrftrIF5Ht2PFDxKKFOct/awAE
# WgHQMVHol9ZLSyd/pYMbaC0IZ+XBW9xhdkkmUV/KbUOiL7g98M/yzRyqUOZ1/IY7
# Ay0YbMniIibJrPcgFp73WDnRDKtVutShPSZQZAdtFwXnuiWl8eFARK3PmLqEm9Us
# VX+55DbVIz33Mbhba0HUTEYv3yJ1fwKGxPBsP/MgTECimh7eXomvMm0/GPxX2uhw
# Ccs/YLxDnBdVVlxvDjHjO1cuwbOpkiJGHmLXXVNbsdXUC2xBrq9fLrfe8IBsA4ho
# pwsCj8hTuwKXJlSTrZcPRVSccP5i9U28gZ7OMzoJGlxZ5384OKm0r568Mo9TYrqz
# KeKZgFo0fj2/0iHbj55hc20jfxvK3mQi+H7xpbzxZOFGm/yVQkpo+ffv5gdhp+hv
# 1GDsvJOtJinJmgGbBFZIThbqI+MHvAmMmkfb3fTxmSkop2mSJL1Y2x/955S29Gu0
# gSJIkc3z30vU/iXrMpWx2tS7UVfVP+5tKuzGtgkP7d/doqDrLF1u6Ci3TpjAZdeL
# LlRQZm867eVeXED58LXd1Dk6UvaAhvmWYXoiLz4JA5gPBcz7J311uahxCweNxE+x
# xxR3kT0WKzASo5G/PyDez6NHdIUKBeE3jDPs2ACc6CkJ1Sji4PKWVT0/MYIGMTCC
# Bi0CAQEwaTBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2AhEA
# h4S8tN9yByR3E9jATIZw9DAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUH/GxKGukfUU1Vnb5lIAi
# XKQ7KgMwDQYJKoZIhvcNAQEBBQAEggIAsvGHlipbuGBLUXxB112WhrVPKCvVxh5x
# 6rREpy0Q+JmURYUZU6LHCT1qALJdMEvZN/8CoFzoPbzDNseZSPbaeOGtUDK8Dsc/
# XJXomPNa3oTulv7uA2jEZaE4eBQNACQEKRL3JPwdbKyEVE8fzqii90gBW3p/J+n1
# VAGSaUshMMBD/lG8EjizronFDnoLG0BMyMJF6XIwbgoFIpaq2DwxRu79D0hepfiz
# 1avBisTqz1fK2fmR+9DPmegvglcjIbnnxDNIs4zwUweMNefP4XPQ+1bE3qMmxJkZ
# 1f89JUYv8E9sb3HmIwTU5UPpF4oi4jZ6qJ1R2BoMqmtND2IPSpScI5h7DLwNmMmT
# 22YPQUBF+XNkA7pDXVsiqPL/XDCy/griGhEp9sUuyws2JdpFIJ9rX4wLnUEpG9d5
# NgA1IQiZmSsqwPY7xRKfKwzOCeD8bWlJbcykMMwT3WVeAFcG4z2nMWMlyRuznl6R
# 3AdPx3Z0k5/g1DjszExKEBsJnz3Wc1ykRwgc+iXl/FqiM0RYlegcJPqebfcSIGAj
# NBdP1u6jTNph9bdTGQzWKkrTYuaeThPqHFl8/3WlKffU3BrapWvwpEhM8tk/IRAF
# B8yE3EqQbLjDFmc87bq3XhLtSshIQ7dhpts/WUsA7KYZokEZgrb4o8UbsCXjZ0Mj
# hAqN8yYwDZihggMjMIIDHwYJKoZIhvcNAQkGMYIDEDCCAwwCAQEwajBVMQswCQYD
# VQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNgIRAKQpO24e3denNAiHrXpO
# tyQwDQYJYIZIAWUDBAICBQCgeTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwG
# CSqGSIb3DQEJBTEPFw0yNjAzMDExMDAwMDNaMD8GCSqGSIb3DQEJBDEyBDDu2eBb
# jSlf+eUIWgeH6AGgEVqtSydfV8IAEykm+R7+k5qWDO6CQ67l/ycGXm7oTTIwDQYJ
# KoZIhvcNAQEBBQAEggIASNKDfRRWGDZi28+dR9GVRrj2alVvvs21dc4rbkBev7CM
# b6e22ZVqVX9chAm/5OMY8bgHAsa5P2L2Hq4BilKzb/hPqxce0c+M9lsa0mpbcryi
# s1QT/Z9QukcU9SxmOUZi5H3J7tmERKrtxoT+BKF58wBH8H6yijd4sbvf77Ook46L
# uZhSUQuNRHrLqx2zw0qSSgiRZVzOPPzxaX8uE2AXFTyZAs+yZdCwau16X/kggpAW
# oSvhi6oXJXqLyZ61XKhd4QtclekuLp0BpEorSp8+NVSvAyTmteFW4qiRGUER8Ivu
# F0+v+83WgeVWjjNITnCZU+gqivdAnU/fcvHiwxHAUziCH4iJHx3q4KjAxawQtpzA
# dS1RI3X0HSnpSMC/Ki2fBle7fy3dyJagiqOTDOJOLsYvkcvZmWUL6XTYs3sIaMN5
# qwE8MljidpOShTrW3Ca1/ez3m7kSW6zA3F/OX696Swc+lT3J0dYUGowZOJheGw7S
# K4qr83Eno93HSm4qU824Yhy4njOltIrD4TItB/iyXIxtkHCNFatXLSyP17m6oYSS
# 1lvBFaF6ZDQmEjNxUZspjCYlrIQpod5iw1UU5J33xnsXjr0DSSFYuHCa646vgBrP
# 6l1pZYBrXd8VcpWtnGOwrO+yNwsfSadhRfpqRTIGMXNDzUwuTpJm2C3/gm4Ory4=
# SIG # End signature block
