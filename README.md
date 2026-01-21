# Entra-PIM

PowerShell module for managing Microsoft Entra PIM (Privileged Identity Management) role activations and deactivations. Supports both **Entra ID roles** and **Azure Resource roles** with browser-based authentication.

## Features

- **Dual PIM Support**: Manage both Entra ID roles and Azure Resource roles from one tool
- **Cross-Platform**: Works on Windows and macOS
- **Browser Authentication**: Secure authentication with ForceLogin prompt
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

### Use a Custom App Registration (Optional)

If your organization requires using a dedicated app registration for delegated auth, provide ClientId and TenantId:

```powershell
Start-EntraPIM -ClientId "<appId>" -TenantId "<tenantId>"
```

When both are provided, authentication uses the supplied app; otherwise, the default interactive flow is used.

**App Registration Requirements:**
- Platform: Mobile and desktop applications
- Redirect URI: `http://localhost`
- Allow public client flows: Yes
- API Permissions (delegated): `RoleManagement.ReadWrite.Directory`, `Directory.Read.All`

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

## What's New in 2.0.0

- **Azure Resource Roles**: Full support for Azure Resource PIM alongside Entra ID roles
- **Workflow Selector**: Choose between Entra ID and Azure Resource PIM at startup
- **Cross-Platform**: Now works on macOS in addition to Windows
- **Silent Prerequisites**: Only shows installation output when modules need installing

## Tags

Entra, PIM, Azure, Identity, Governance, MicrosoftGraph, Privileged, RoleManagement, AzureResources, CrossPlatform
