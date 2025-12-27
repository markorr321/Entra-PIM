# Entra-PIM

PowerShell module for managing Microsoft Entra PIM role activations and deactivations.

## Installation

### One-time setup (register the GitHub repository)

```powershell
Register-PSResourceRepository -Name 'EntraPIM-GH' -Uri 'https://api.github.com/repos/YOUR_USERNAME/Entra-PIM/releases' -Trusted
```

### Install the module

```powershell
Install-PSResource -Name Entra-PIM -Repository EntraPIM-GH
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
- Microsoft.Graph.Authentication module
- Microsoft.Graph.Identity.Governance module

## Updating

```powershell
Update-PSResource -Name Entra-PIM -Repository EntraPIM-GH
```
