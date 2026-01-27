#Requires -Version 7.0

# Entra-PIM PowerShell Module
# Simple wrapper to run the PIM management script

function Start-EntraPIM {
    <#
    .SYNOPSIS
        Launches the Entra PIM role management tool.

    .DESCRIPTION
        Opens an interactive console application for managing Microsoft Entra
        PIM role activations and deactivations with browser-based authentication.

    .PARAMETER ClientId
        Client ID of the app registration to use for delegated auth.

    .PARAMETER TenantId
        Tenant ID to use with the specified app registration.

    .EXAMPLE
        Start-EntraPIM

    .EXAMPLE
        Start-EntraPIM -ClientId "b7463ebe-e5a7-4a1a-ba64-34b99135a27a" -TenantId "51eb883f-451f-4194-b108-4df354b35bf4"
    #>
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = "Client ID of the app registration to use for delegated auth")]
        [string]$ClientId,

        [Parameter(HelpMessage = "Tenant ID to use with the specified app registration")]
        [string]$TenantId
    )

    # Run the main script
    $scriptPath = Join-Path $PSScriptRoot "Entra-PIM.ps1"
    & $scriptPath -ClientId $ClientId -TenantId $TenantId
}

Export-ModuleMember -Function 'Start-EntraPIM'
