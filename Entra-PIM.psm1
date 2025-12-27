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
    
    .EXAMPLE
        Start-EntraPIM
    #>
    [CmdletBinding()]
    param()
    
    # Run the main script
    $scriptPath = Join-Path $PSScriptRoot "PIM-Global-SelfActivate-Browser-Optimized.ps1"
    & $scriptPath
}

Export-ModuleMember -Function 'Start-EntraPIM'
