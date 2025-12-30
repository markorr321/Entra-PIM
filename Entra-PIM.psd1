@{
    # Module manifest for Entra-PIM
    # Generated for PSResourceGet / GitHub Releases distribution

    # Script module or binary module file associated with this manifest
    RootModule = 'Entra-PIM.psm1'

    # Version number of this module (SemVer format for PSResourceGet)
    ModuleVersion = '1.6.1'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'markorr321'

    # Company or vendor of this module
    CompanyName = 'Orr365'

    # Copyright statement for this module
    Copyright = '(c) 2024. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Simplify Microsoft Entra PIM role management with an interactive console experience. Features Windows native SSO via WAM (Web Account Manager), automatic step-up MFA handling, one-command activation/deactivation of eligible roles, and auto-installation of dependencies. Just run Start-EntraPIM - no app registration or complex configuration required.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()  # Dependencies checked at runtime instead

    # Functions to export from this module - just one simple command
    FunctionsToExport = @('Start-EntraPIM')

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
            Tags = @('Entra', 'PIM', 'Azure', 'Identity', 'Governance', 'MicrosoftGraph', 'Privileged', 'RoleManagement')

            # A URL to the license for this module
            LicenseUri = 'https://github.com/markorr321/Entra-PIM/blob/main/LICENSE'

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/markorr321/Entra-PIM'

            # A URL to an icon representing this module
            IconUri = 'https://raw.githubusercontent.com/markorr321/Entra-PIM/main/icon.png'

            # ReleaseNotes of this module
            ReleaseNotes = @'
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
