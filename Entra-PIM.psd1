@{
    # Module manifest for Entra-PIM
    # Generated for PSResourceGet / GitHub Releases distribution

    # Script module or binary module file associated with this manifest
    RootModule = 'Entra-PIM.psm1'

    # Version number of this module (SemVer format for PSResourceGet)
    ModuleVersion = '2.2.4'

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
            Tags = @('Entra', 'PIM', 'Azure', 'Identity', 'Governance', 'MicrosoftGraph', 'Privileged', 'RoleManagement', 'AzureResources', 'CrossPlatform', 'macOS')

            # A URL to the license for this module
            LicenseUri = 'https://github.com/markorr321/Entra-PIM/blob/main/LICENSE'

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/markorr321/Entra-PIM'

            # A URL to an icon representing this module
            IconUri = 'https://raw.githubusercontent.com/markorr321/Entra-PIM/main/icon.png'

            # ReleaseNotes of this module
            ReleaseNotes = @'
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
