function Remove-GkGroupMember {
    <#
    .SYNOPSIS
        Remove a member from one or more groups.

    .DESCRIPTION
        Removes the specified directory object from a group's membership
        (DELETE /groups/{id}/members/{memberId}/$ref) — this removes only the membership link, not
        the object itself.

        State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts group IDs from the
        pipeline and yields a PSGraphKit.GroupMemberResult per group; failures warn and continue.
        Requires GroupMember.ReadWrite.All (role-assignable groups also need
        RoleManagement.ReadWrite.Directory).

    .PARAMETER GroupId
        One or more group object IDs. Accepts pipeline input (incl. by the Id property).

    .PARAMETER MemberId
        Object ID of the member to remove.

    .EXAMPLE
        Remove-GkGroupMember -GroupId $groupId -MemberId $userId

        Remove one member (prompts for confirmation).

    .EXAMPLE
        Remove-GkGroupMember -GroupId $groupId -MemberId $userId -WhatIf

        Preview the removal.

    .EXAMPLE
        $groups | Remove-GkGroupMember -MemberId $userId -Confirm:$false | Where-Object Outcome -eq 'Failed'

    .OUTPUTS
        PSGraphKit.GroupMemberResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.GroupMemberResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string[]] $GroupId,

        [Parameter(Mandatory)]
        [string] $MemberId
    )

    begin {
        Test-GkConnection -FunctionName 'Remove-GkGroupMember' -Caller $PSCmdlet | Out-Null
        $encMember = [uri]::EscapeDataString($MemberId)
    }

    process {
        foreach ($gid in $GroupId) {
            if ([string]::IsNullOrWhiteSpace($gid)) { continue }
            if (-not $PSCmdlet.ShouldProcess($gid, "Remove member $MemberId")) { continue }

            $enc = [uri]::EscapeDataString($gid)
            $outcome = 'Removed'
            $errMsg = $null
            try {
                Invoke-GkGraphRequest -Method DELETE -Uri "/groups/$enc/members/$encMember/`$ref" -CallerFunction 'Remove-GkGroupMember' | Out-Null
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to remove member from group '$gid': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName = 'PSGraphKit.GroupMemberResult'
                GroupId    = $gid
                MemberId   = $MemberId
                Action     = 'RemoveMember'
                Outcome    = $outcome
                Error      = $errMsg
            }
        }
    }
}
