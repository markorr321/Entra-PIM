# Entra-PIM

PowerShell module for managing Microsoft Entra PIM (Privileged Identity Management) role activations and deactivations with browser-based authentication.

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
2. Show your eligible/active PIM roles
3. Let you activate or deactivate roles interactively

## Requirements

- PowerShell 7.0+

## Updating

### Using PowerShellGet

```powershell
Update-Module -Name Entra-PIM
```

### Using PSResourceGet

```powershell
Update-PSResource -Name Entra-PIM
```

## Tags

Entra, PIM, Azure, Identity, Governance, MicrosoftGraph, Privileged, RoleManagement
