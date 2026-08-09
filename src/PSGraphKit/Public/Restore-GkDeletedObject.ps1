function Restore-GkDeletedObject {
    <#
    .SYNOPSIS
        Restore a soft-deleted directory object from the 30-day recycle window.

    .DESCRIPTION
        Calls POST /directory/deletedItems/{id}/restore. This is the write counterpart to
        Get-GkDeletedItem, and the recovery path for anything Remove-GkStaleGuest -Delete or
        Disable-GkStaleDevice -Delete removed by mistake.

        Restoring a user also restores their mailbox, license assignments and group memberships.
        A user whose userPrincipalName or proxy addresses now collide with a live object cannot be
        restored until the conflict is resolved — Graph rejects it, and the error says which.

        State-changing: supports -WhatIf / -Confirm and prompts by default.

        Scopes depend on the object type and only the one in use is validated:
        User.DeleteRestore.All for users, Group.ReadWrite.All for groups,
        Application.ReadWrite.All for applications and service principals,
        AdministrativeUnit.ReadWrite.All for administrative units.

    .PARAMETER Id
        One or more deleted object IDs. Accepts pipeline input, including by the Id property so
        Get-GkDeletedItem output can be piped straight in.

    .PARAMETER Type
        The directory object type being restored. Determines which scope is validated. Accepts
        pipeline input by the ObjectType property, so Get-GkDeletedItem supplies it automatically.

    .EXAMPLE
        Get-GkDeletedItem -Type User -ExpiringInDays 3 | Restore-GkDeletedObject -WhatIf

        Preview restoring every deleted user about to be purged.

    .EXAMPLE
        Restore-GkDeletedObject -Id $objectId -Type User

        Restore one user (prompts for confirmation).

    .EXAMPLE
        Get-GkDeletedItem -Type Group | Where-Object DisplayName -like 'Project*' |
            Restore-GkDeletedObject -Confirm:$false

    .OUTPUTS
        PSGraphKit.RestoreResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.RestoreResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]] $Id,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('ObjectType')]
        [ValidateSet('User', 'Group', 'Application', 'ServicePrincipal', 'AdministrativeUnit')]
        [string] $Type
    )

    begin {
        # Validate lazily: -Type binds per pipeline item, so the scope check belongs in process.
        $validated = @{}
    }

    process {
        if (-not $validated.ContainsKey($Type)) {
            Test-GkConnection -FunctionName 'Restore-GkDeletedObject' -Variant $Type -Caller $PSCmdlet | Out-Null
            $validated[$Type] = $true
        }

        foreach ($oid in $Id) {
            if ([string]::IsNullOrWhiteSpace($oid)) { continue }
            if (-not $PSCmdlet.ShouldProcess($oid, "Restore deleted $Type")) { continue }

            $enc = [uri]::EscapeDataString($oid)
            $outcome = 'Restored'
            $errMsg = $null
            $displayName = $null
            try {
                $resp = Invoke-GkGraphRequest -Raw -Method POST -Uri "/directory/deletedItems/$enc/restore" `
                    -CallerFunction 'Restore-GkDeletedObject'
                $displayName = [string](Get-GkDictValue $resp 'displayName')
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to restore $Type '$oid': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName  = 'PSGraphKit.RestoreResult'
                Id          = $oid
                ObjectType  = $Type
                DisplayName = $displayName
                Action      = 'Restore'
                Outcome     = $outcome
                Error       = $errMsg
            }
        }
    }
}
