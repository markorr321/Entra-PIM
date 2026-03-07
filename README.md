# Entra-PIM

PowerShell module for managing Microsoft Entra PIM (Privileged Identity Management) role activations and deactivations through an interactive console experience. Supports **Entra ID roles**, **Azure Resource roles**, and **Groups PIM** with browser-based authentication. Features automatic step-up MFA handling, one-command activation/deactivation, and auto-installation of dependencies. Cross-platform compatible with **Windows**, **macOS**, and **Linux**. Just run `Start-EntraPIM` — works out of the box with no configuration, or bring your own app registration for full control.

## Features

- **Full PIM Support**: Manage Entra ID roles, Azure Resource roles, and Groups PIM from one tool
- **Cross-Platform**: Works on Windows and macOS
- **Browser Authentication**: Secure authentication with ForceLogin prompt
- **Persistent Configuration**: Save custom app registration settings via environment variables
- **Step-up MFA**: Automatic handling of MFA/claims challenges for privileged roles
- **Interactive Console**: Easy-to-use TUI with back navigation and live countdown timers
- **Auto-Dependencies**: Automatically installs required modules on first run
- **Smart Duration Handling**: If requested duration exceeds a role's policy maximum, each role activates for its individual policy limit

## Demo

![Entra-PIM Demo](Entra-PIM.gif)

## Installation

### Using PowerShellGet

```powershell
Install-Module -Name Entra-PIM -Repository PSGallery
```

### Using PSResourceGet

```powershell
Install-PSResource -Name Entra-PIM -Repository PSGallery
```

## Updating

The module automatically checks for updates and prompts you when a new version is available. It detects your installation method (PowerShellGet or PSResourceGet) and uses the correct update command.

To update manually:

```powershell
# If installed with Install-Module
Update-Module -Name Entra-PIM

# If installed with Install-PSResource
Update-PSResource -Name Entra-PIM
```

## Usage

```powershell
Start-EntraPIM
```

That's it! The tool will:
1. Open your browser for authentication
2. Let you choose between Entra ID Roles, Entra Group Roles, or Azure Resource Roles
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

**Additional permissions for Groups PIM:**
  - `PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup`
  - `PrivilegedEligibilitySchedule.Read.AzureADGroup`
  - `RoleManagementPolicy.Read.AzureADGroup`

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
| Ctrl+D | Deselect all |
| ENTER | Confirm |
| ESC | Step back (activation form) |
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

### Update Notifications

Entra-PIM automatically checks for updates once per day and notifies you when a newer version is available on PowerShell Gallery. The check happens when you first import the module in a new PowerShell session.

**Example notification:**
```
[!] Entra-PIM update available: 2.1.0 -> 2.2.0 | Run: Update-Module -Name Entra-PIM
```

The version check:
- Runs automatically once per 24 hours
- Uses cached results to minimize network calls
- Has a 5-second timeout to prevent delays
- Silently handles offline scenarios (no errors if network is unavailable)
- Works cross-platform (Windows, macOS, Linux)

**To disable update notifications:**
```powershell
[System.Environment]::SetEnvironmentVariable('ENTRAPIM_DISABLE_UPDATE_CHECK', 'true', 'User')
```

## What's New in 2.3.4

- **Linux Color Fix**: Fixed console color rendering on Linux where terminals report invalid (-1) color values
- **Cross-Platform Terminal Compatibility**: Defensive Write-Host handling ensures consistent display across all platforms

## What's New in 2.3.3

- **Enter Key Fix**: Pressing Enter with no workflow selected no longer exits the app
- **Updated Platform Docs**: Documentation now correctly lists Linux alongside Windows and macOS
- **Updated Descriptions**: Module and README descriptions now highlight all key features

## What's New in 2.3.1

- **Groups PIM Support**: Activate/deactivate Entra Groups PIM memberships (member and owner roles)
- **Policy Duration Display**: Selection menu shows each group's maximum allowed duration
- **Activation Preview**: When requested duration exceeds policy limits, preview shows which groups will be capped
- **Smart Duration Capping**: Each group activates for its individual policy maximum if your request exceeds it
- **Azure Browse All Roles**: New view mode to browse roles across all subscriptions or filter by subscription
- **Branded Auth Pages**: Custom-styled success and error pages in the browser after authentication
- **Deactivation Summaries**: Clear success/fail/skipped totals displayed after deactivation operations
- **Ctrl+A Fix**: Select all now works correctly in Azure role menus
- **Version Display**: Header now shows the current module version

### Previous Highlights

**Version 2.3.0**
- **Back Navigation**: Every menu now has a `← Back` item — no more restarting the workflow if you pick the wrong option
- **Live Countdown Timers**: Deactivation role selection shows expiration time counting down in real time (updates every second)
- **Smart Azure Back**: Back from the Azure action menu returns to subscription selection, not all the way to the workflow selector
- **Activation Step-Back**: ESC navigates backward through the activation form (reason → duration → role selection)
- **Countdown Back**: The 5-minute deactivation countdown screen now lets you go back instead of waiting

**Version 2.2.8**
- Fixed Azure PIM group-based role activation (uses user OID from JWT token)
- Consistent activation/deactivation UI messages between Entra and Azure workflows
- Simplified exit handling

**Version 2.2.0**
- Automatic update notifications from PowerShell Gallery (once per 24 hours)
- Smart caching with 5-second timeout for non-blocking checks

**Version 2.1.0**
- Configure-EntraPIM command for persistent custom app registration configuration
- Clear-EntraPIMConfig and Get-EntraPIMHelp commands
- macOS PowerShell profile integration

**Version 2.0.0**
- Azure Resource Roles support alongside Entra ID roles
- Workflow selector for choosing between Entra ID and Azure Resource PIM
- Cross-platform support (Windows and macOS)
- Silent prerequisite installation

## Tags

Entra, PIM, Azure, Identity, Governance, MicrosoftGraph, Privileged, RoleManagement, AzureResources, Groups, CrossPlatform, PowerShell
