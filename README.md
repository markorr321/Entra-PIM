# Entra-PIM

PowerShell module for managing Microsoft Entra PIM (Privileged Identity Management) role activations and deactivations. Supports both **Entra ID roles** and **Azure Resource roles** with browser-based authentication.

## Features

- **Dual PIM Support**: Manage both Entra ID roles and Azure Resource roles from one tool
- **Cross-Platform**: Works on Windows and macOS
- **Browser Authentication**: Secure authentication with ForceLogin prompt
- **Persistent Configuration**: Save custom app registration settings via environment variables
- **Step-up MFA**: Automatic handling of MFA/claims challenges for privileged roles
- **Interactive Console**: Easy-to-use TUI for role selection
- **Auto-Dependencies**: Automatically installs required modules on first run

## Installation

### Using PowerShellGet

```powershell
Install-Module -Name Entra-PIM -Repository PSGallery
```

### Using PSResourceGet

```powershell
Install-PSResource -Name Entra-PIM -Repository PSGallery
```

## Usage

```powershell
Start-EntraPIM
```

That's it! The tool will:
1. Open your browser for authentication
2. Let you choose between Entra ID or Azure Resource PIM
3. Show your eligible/active PIM roles
4. Let you activate or deactivate roles interactively

## Configuration

### Persistent Configuration (Recommended for Custom App Registrations)

If your organization requires a custom app registration, you can configure it once and use `Start-EntraPIM` without parameters:

```powershell
# Configure once
Configure-EntraPIM
```

You'll be prompted to enter your ClientId and TenantId. These are saved as environment variables that persist across PowerShell sessions.

**On Windows:** Configuration is saved to user-level environment variables automatically.

**On macOS:** You'll be offered the option to add the configuration to your PowerShell profile for persistence across sessions.

After configuration, simply run:

```powershell
Start-EntraPIM
```

To remove the saved configuration and return to default authentication:

```powershell
Clear-EntraPIMConfig
```

### One-Time Custom App Registration

For temporary use of a custom app registration (single session only):

```powershell
Start-EntraPIM -ClientId "<appId>" -TenantId "<tenantId>"
```

### App Registration Requirements

When using a custom app registration, configure it with:

- **Platform**: Mobile and desktop applications
- **Redirect URI**: `http://localhost`
- **Allow public client flows**: Yes
- **API Permissions** (delegated):
  - `User.Read`
  - `RoleAssignmentSchedule.ReadWrite.Directory`
  - `RoleEligibilitySchedule.ReadWrite.Directory`
  - `RoleManagement.Read.Directory`
  - `RoleManagementPolicy.Read.Directory`

## Available Commands

- **Start-EntraPIM** - Launch the PIM role management tool
- **Configure-EntraPIM** - Set up persistent custom app registration configuration
- **Clear-EntraPIMConfig** - Remove saved configuration
- **Get-EntraPIMHelp** - Display comprehensive help and command reference

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ↑/↓ | Navigate |
| SPACE | Toggle selection |
| Ctrl+A | Select all |
| ENTER | Confirm |
| Ctrl+H | Help |
| Ctrl+Q | Exit |

## Requirements

- PowerShell 7.0+
- Required modules (auto-installed):
  - Az.Accounts
  - Microsoft.Graph.Authentication
  - Microsoft.Graph.Identity.DirectoryManagement
  - Microsoft.Graph.Identity.Governance

## Updating

### Using PowerShellGet

```powershell
Update-Module -Name Entra-PIM
```

### Using PSResourceGet

```powershell
Update-PSResource -Name Entra-PIM
```

## What's New in 2.1.0

- **Configure-EntraPIM Command**: Persistent configuration via environment variables - configure once, use everywhere
- **Clear-EntraPIMConfig Command**: Easy removal of saved configuration
- **Get-EntraPIMHelp Command**: Comprehensive built-in help and command reference
- **Visual Confirmation**: See which app registration is being used during authentication
- **Windows Terminal Fix**: Ctrl+Q now properly closes the terminal in Entra workflow
- **MSAL Conflict Fix**: Resolved assembly conflicts when multiple Microsoft modules are loaded
- **macOS Profile Integration**: Automatic PowerShell profile integration for persistent configuration on macOS

### Previous Highlights

**Version 2.0.8**
- Custom App Registration support with `-ClientId` and `-TenantId` parameters
- Least-privilege Graph permissions for better security
- macOS compatibility improvements

**Version 2.0.0**
- Azure Resource Roles support alongside Entra ID roles
- Workflow selector for choosing between Entra ID and Azure Resource PIM
- Cross-platform support (Windows and macOS)
- Silent prerequisite installation

## Tags

Entra, PIM, Azure, Identity, Governance, MicrosoftGraph, Privileged, RoleManagement, AzureResources, CrossPlatform
