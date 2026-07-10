function Disable-GkStaleDevice {
    <#
    .SYNOPSIS
        Disable (default) or delete stale Entra devices.

    .DESCRIPTION
        By default blocks the device (PATCH /devices/{id} accountEnabled=false). With -Delete it
        deletes the device (DELETE /devices/{id}); deletion is a 30-day soft-delete. Typically fed
        from Get-GkDeviceInventory -StaleOnly.

        State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts devices from the
        pipeline (by the Id property, so Get-GkDeviceInventory output pipes in) and yields a
        PSGraphKit.DeviceDisableResult per device; failures warn and continue.

        Delegated device writes use Directory.AccessAsUser.All (there is no delegated
        Device.ReadWrite.All) and require a supporting Entra role — Cloud Device Administrator to
        enable/disable, Intune Administrator to delete.

    .PARAMETER Id
        One or more device OBJECT IDs (the Id from Get-GkDeviceInventory, not the deviceId GUID).
        Accepts pipeline input by the Id property; -DeviceId remains a back-compat alias. Binding to
        Id — not DeviceId — is deliberate: Get-GkDeviceInventory emits BOTH properties, /devices/{id}
        needs the object id, and PowerShell binds a parameter's formal name over its alias.

    .PARAMETER Delete
        Delete the device (soft-delete) instead of only disabling it.

    .EXAMPLE
        Get-GkDeviceInventory -StaleOnly -StaleDays 180 | Disable-GkStaleDevice -WhatIf

        Preview disabling devices with no activity for 180+ days.

    .EXAMPLE
        Get-GkDeviceInventory -StaleOnly -StaleDays 365 | Disable-GkStaleDevice -Confirm:$false

        Disable devices inactive 365+ days.

    .EXAMPLE
        Disable-GkStaleDevice -DeviceId 11111111-1111-1111-1111-111111111111 -Delete

        Delete one device by object id (prompts for confirmation).

    .OUTPUTS
        PSGraphKit.DeviceDisableResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.DeviceDisableResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DeviceId')]
        [string[]] $Id,

        [switch] $Delete
    )

    begin {
        Test-GkConnection -FunctionName 'Disable-GkStaleDevice' | Out-Null
    }

    process {
        foreach ($did in $Id) {
            if ([string]::IsNullOrWhiteSpace($did)) { continue }

            $action = if ($Delete) { 'Delete device (soft-delete)' } else { 'Disable device (accountEnabled = false)' }
            if (-not $PSCmdlet.ShouldProcess($did, $action)) { continue }

            $enc = [uri]::EscapeDataString($did)
            $outcome = if ($Delete) { 'Deleted' } else { 'Disabled' }
            $errMsg = $null
            try {
                if ($Delete) {
                    Invoke-GkGraphRequest -Method DELETE -Uri "/devices/$enc" -CallerFunction 'Disable-GkStaleDevice' | Out-Null
                }
                else {
                    Invoke-GkGraphRequest -Method PATCH -Uri "/devices/$enc" -Body @{ accountEnabled = $false } -CallerFunction 'Disable-GkStaleDevice' | Out-Null
                }
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to $(if ($Delete) { 'delete' } else { 'disable' }) device '$did': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName = 'PSGraphKit.DeviceDisableResult'
                DeviceId   = $did
                Action     = if ($Delete) { 'DeleteDevice' } else { 'DisableDevice' }
                Outcome    = $outcome
                Error      = $errMsg
            }
        }
    }
}
