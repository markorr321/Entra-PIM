@{
    # Module manifest for Entra-PIM
    # Generated for PSResourceGet / GitHub Releases distribution

    # Script module or binary module file associated with this manifest
    RootModule = 'Entra-PIM.psm1'

    # Version number of this module (SemVer format for PSResourceGet)
    ModuleVersion = '2.3.1'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'markorr321'

    # Company or vendor of this module
    CompanyName = 'Orr365'

    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Manage Microsoft Entra PIM roles for both Entra ID and Azure Resources with an interactive console experience. Features browser-based authentication with ForceLogin, cross-platform support (Windows/macOS), automatic step-up MFA handling, one-command activation/deactivation of eligible roles, and auto-installation of dependencies. Just run Start-EntraPIM - no app registration or complex configuration required.'

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
# MIIr0AYJKoZIhvcNAQcCoIIrwTCCK70CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAh1TxkSMwKPrs8
# sOJoS1xTeGwEQZ1WGpKjyltxxngueqCCJOQwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# hvcNAQkEMSIEIOLCZCQ6vlrai40/6OL/fLT0QGdSRh2FBEUczDnvmuyvMA0GCSqG
# SIb3DQEBAQUABIICAKSfOrcHkbxQ68PLJ4lIWMBT5wFtxn9aYXm1ScyhFpxBOFav
# tZX8VrmF2rtsjk1yRZ6ErE1pJR9k8GllMJJDYsjyBBvSkpab3EdxedLpo1a4b7Yu
# Z2iKcqSLkmgc+c8zqlSlRYE+6hoOpdfeJQ0mWqF0CmUcNlNJD1PutD9MOIJg/SC6
# scWnAbaqku5Pjrh3dKDfk7c0+YnZgr35h9KQ/WjPuMF/KxUimDT0Gsi/DxfovCQ8
# gbzUIFuuY1PttNYEL5B5raZPkg4WFvTVap6SSje4ZMb5q+++WNBf0X1kvZpb3am8
# +kCRk0LzLoIakoSFSiwWJfcB/N2Gmbh4K/JiQZKa0Gdc/QTn/cWlA/Bi2//F8NWj
# O8ACKhZURjer4wlmzT9K65EGu2xAq/rBNjfvCR03WnDroTMG/OFafrMdt1IB80cI
# W1QjIQR0sCJ6DTnsNUCRL7PXIrimlP9kWdqTuiMJORipxFlNFZfOTMasHYpRx9JY
# HTzsSvBmdnvtwLGv53ZlxP4GNbByi6ggadDT1Ms3m2vQArCMWn/60xJ1ETl7Ysix
# iipfxhequ8wPHuNcHIVK23Z16+LHkbRnqpGYp1LgoQnbVTR+Grp2WIXdpclG7JiM
# fpacdRirlEv29hFVbpxcDzirpDD9RUuvNnKEx4pqlqQV321ad2DeJttngfm9oYID
# IzCCAx8GCSqGSIb3DQEJBjGCAxAwggMMAgEBMGowVTELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMg
# VGltZSBTdGFtcGluZyBDQSBSMzYCEQCkKTtuHt3XpzQIh616TrckMA0GCWCGSAFl
# AwQCAgUAoHkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUx
# DxcNMjYwMjI4MTAzOTA2WjA/BgkqhkiG9w0BCQQxMgQw4l1tGJ4i7mpggAbKKrR0
# 8MPmfABj1F4QJR2sqOqAxxFgER9Dq6WQJgWnW9ABr+TlMA0GCSqGSIb3DQEBAQUA
# BIICAIsr/vC8y0BYaJEqrCf9MMqSNFVjEg8rj373I5guOenzrdU9kb/1mVhbaxfL
# mrTuEi8EJHeFJJBE84pyFOArKqtoEOQPnNgOowTDz1nQuCut11pOMqeZ7ajErK2z
# 6TFgIRFPrtu9UD3ClL5eoPVVSbQZrm5YWdYA2u5tHcQnZPqwkw3Oe6Ljb/QZSS02
# FniCQmhkCpjmAQFgKFeUfNU6Y2QNhvuf0KIe2vVsenw+RkZfNKMsFFxovF37pLz5
# 1UtD+8gQtu94DzHsGM/pIStCsHurPpgfUXPTz3CuP2K+6QJAiWeDdWJfgVP1QuTh
# xyHAoHY3je9SVOTxv1vFqv/0mmua/GY072j0OhIedGRxiLDZZBpzQeoz2Fwk77pL
# FvUf7m80cmUhohK28q6nbojEqyi3t7qOYHXc/LfY6WZ6cCY581k/G3dV2M1EH/vT
# lShVaytv14EMjkg3yAoXwDVWpGVZoO2TVQLircOVHt7wjjVA84xSJfXZhAjp62Xv
# SH4I7nlAEzrIftIMz56Nq0D3xPsbAjktz8d9hqmNfUYfoEYb2Fy8Q0kv006ICylI
# TTS1wMOc2AsJYsUEFI029XYClx5Xojnl40jEw4LqpCWGY8j+L++TAM2zcx7IX1v7
# f5/XaO/Na+7cRPsPwwArzDXA565RXe3VG2ujf0Jde5e0lEs/
# SIG # End signature block
