# Create GitHub Release v2.2.0

# Create release notes file
@"
## What's New in v2.2.0

### New Features
- **Automatic Update Notifications** - Entra-PIM now checks PowerShell Gallery once per 24 hours and displays an inline red notification when a newer version is available
- **Smart Caching** - Version checks are cached for 24 hours to minimize network calls and respect PowerShell Gallery API
- **Optional Disable** - Update notifications can be disabled via the ENTRAPIM_DISABLE_UPDATE_CHECK environment variable

### Improvements
- Non-blocking version check with 5-second timeout ensures module import isn't delayed
- Graceful offline handling - silently fails if network is unavailable (no errors)
- Cross-platform cache support (Windows, macOS, Linux)

## Installation

Using PSResourceGet:
``````powershell
Install-PSResource -Name Entra-PIM -Repository PSGallery
``````

Using PowerShellGet:
``````powershell
Install-Module -Name Entra-PIM -Repository PSGallery
``````

## Updating

Using PSResourceGet:
``````powershell
Update-PSResource -Name Entra-PIM
``````

Using PowerShellGet:
``````powershell
Update-Module -Name Entra-PIM
``````

---

**Full Changelog**: https://github.com/markorr321/Entra-PIM/compare/v2.1.0...v2.2.0
"@ | Out-File -FilePath release-notes.md -Encoding utf8

# Create the release (without attaching .nupkg)
gh release create v2.2.0 --title "v2.2.0" --notes-file release-notes.md

# Clean up
Remove-Item release-notes.md

Write-Host "Release created successfully!" -ForegroundColor Green
Write-Host "View at: https://github.com/markorr321/Entra-PIM/releases/tag/v2.2.0" -ForegroundColor Cyan
