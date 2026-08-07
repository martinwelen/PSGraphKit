function Set-GkGroupOwner {
    <#
    .SYNOPSIS
        Add an owner to one or more groups (e.g. to remediate ownerless groups).

    .DESCRIPTION
        Calls POST /groups/{id}/owners/$ref to add the specified directory object (a user or service
        principal) as an owner. Typically fed from Get-GkGroupReport -OwnerlessOnly to assign owners
        to ownerless groups.

        State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts groups from the
        pipeline and yields a PSGraphKit.GroupOwnerResult per group; a failure warns and continues
        (adding an existing owner returns a Graph error, reported as Failed). A group is limited to
        100 owners. Owners cannot be set on groups synced from on-premises or created in Exchange.

        Requires Group.ReadWrite.All (or Directory.ReadWrite.All) plus a supporting Entra role
        (e.g. Groups Administrator or User Administrator).

    .PARAMETER GroupId
        One or more group object IDs. Accepts pipeline input (incl. by the Id property, so
        Get-GkGroupReport output pipes in directly).

    .PARAMETER OwnerId
        Object ID of the user or service principal to add as an owner.

    .EXAMPLE
        Set-GkGroupOwner -GroupId 11111111-1111-1111-1111-111111111111 -OwnerId $adaId

        Add an owner to one group (prompts for confirmation).

    .EXAMPLE
        Get-GkGroupReport -OwnerlessOnly | Where-Object GroupType -eq 'Microsoft365' |
            Set-GkGroupOwner -OwnerId $adminId -WhatIf

        Preview assigning an owner to every ownerless Microsoft 365 group.

    .EXAMPLE
        Get-GkGroupReport -OwnerlessOnly | Set-GkGroupOwner -OwnerId $adminId -Confirm:$false |
            Where-Object Outcome -eq 'Failed'

        Assign an owner to all ownerless groups without prompting and inspect any failures.

    .OUTPUTS
        PSGraphKit.GroupOwnerResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.GroupOwnerResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string[]] $GroupId,

        [Parameter(Mandatory)]
        [string] $OwnerId
    )

    begin {
        Test-GkConnection -FunctionName 'Set-GkGroupOwner' -Caller $PSCmdlet | Out-Null
        $encOwner = [uri]::EscapeDataString($OwnerId)
        $ownerRef = "$script:GkGraphBaseUri/v1.0/directoryObjects/$encOwner"
    }

    process {
        foreach ($gid in $GroupId) {
            if ([string]::IsNullOrWhiteSpace($gid)) { continue }

            if (-not $PSCmdlet.ShouldProcess($gid, "Add owner $OwnerId")) { continue }

            $enc = [uri]::EscapeDataString($gid)

            $outcome = 'OwnerAdded'
            $errMsg = $null
            try {
                Invoke-GkGraphRequest -Method POST -Uri "/groups/$enc/owners/`$ref" `
                    -Body @{ '@odata.id' = $ownerRef } `
                    -CallerFunction 'Set-GkGroupOwner' | Out-Null
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to add owner to group '$gid': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName = 'PSGraphKit.GroupOwnerResult'
                GroupId    = $gid
                OwnerId    = $OwnerId
                Action     = 'AddOwner'
                Outcome    = $outcome
                Error      = $errMsg
            }
        }
    }
}
