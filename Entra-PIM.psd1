@{
    # Module manifest for Entra-PIM
    # Generated for PSResourceGet / GitHub Releases distribution

    # Script module or binary module file associated with this manifest
    RootModule = 'Entra-PIM.psm1'

    # Version number of this module (SemVer format for PSResourceGet)
    ModuleVersion = '2.3.5'

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
## 2.3.5
- Fixed macOS/Linux update flow closing terminal window unexpectedly
- Platform-aware post-update behavior (exit on Windows, return on macOS/Linux)

## 2.3.4
- Fixed Linux color rendering issue where console reports invalid (-1) color values
- Defensive Write-Host handling for cross-platform terminal compatibility

## 2.3.3
- Updated module and README descriptions to highlight key features
- Fixed Enter key exiting app when no workflow is selected
- Documentation now correctly lists Linux alongside Windows and macOS

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
# MIIVpQYJKoZIhvcNAQcCoIIVljCCFZICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAReAqqrIfuob/g
# BvFIYjbmSsAvXxp0HWOT3zCKt8VEY6CCEeAwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDcGwjvmXQ4VVNG
# hSxNVcsGqvVWU2j7hadXKuQouD4kLDANBgkqhkiG9w0BAQEFAASCAgAPDJLMvT+B
# XgHn/BWTszStx42SMOHLGaCTS//Cf187hN4jZ5+dWUE/kJjMLzlpMnPjq7xBuD1r
# 3kpH8YoKzdmEdC7hSlhq0PvKnpDsRJv64aAOcm9cyov7qRIWCv/4CobBKfCTpVQA
# VOfsA7slw4HZoMgnTgAk0JKBMRje3R8llO5F46erJn9cqGFmJim7Q2bGkGuGzOy+
# WfSi60SSybpZQOTpJ6BQuTzeVKhXAPxVUoAyRJsZJzbGkLRmHcwyJpuvTt5/zXwr
# AJOG/MHsIiMsLAkW7qKj4/f8MLpOR4lsXJbqEYTN6j1rW+KafSyxR6dgPJeR7Sxp
# by4j7+8c+5kOcLhXnhy2wZ0exIUKfmqv3ciDpOfdkGpRknIJztlGu9mKJ/H3TxmP
# VAyqRioPJa99W+2YOwo6urXAti/3j9VBpTPClFK/3wxhD2QsEX6E/eRUyr71pN91
# KnW8dovPLUvfXz8lJYn7S8V6DvTE+GMWCraUZMiqAXwQWwljMbV7UGlwiKIoIzTR
# IgfMSCMgwkY82Nf5m+Njv6YM/VKgbK1JJxGZojXj2wmlHKvEGHekTrtNdEyP/aV1
# tOcHbRBeY66BweToS/uvNjtx38qdve3EKG6OVsrWD8OeB+y1b6rOs4yR3NexRp7a
# sGUV+a9Gjh2jlsnOSR9dvlM22AA5c0Zt6g==
# SIG # End signature block
