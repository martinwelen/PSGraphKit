function Add-GkGroupMember {
    <#
    .SYNOPSIS
        Add a member (user, group, or service principal) to one or more groups.

    .DESCRIPTION
        Adds the specified directory object as a member (POST /groups/{id}/members/$ref).

        State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts group IDs from the
        pipeline and yields a PSGraphKit.GroupMemberResult per group; failures warn and continue
        (adding an existing member returns a Graph error). Requires GroupMember.ReadWrite.All. Adding
        a member to a role-assignable group additionally requires RoleManagement.ReadWrite.Directory.

    .PARAMETER GroupId
        One or more group object IDs. Accepts pipeline input (incl. by the Id property).

    .PARAMETER MemberId
        Object ID of the user, group, or service principal to add.

    .EXAMPLE
        Add-GkGroupMember -GroupId $groupId -MemberId $userId

        Add one member (prompts for confirmation).

    .EXAMPLE
        Get-GkGroupReport | Where-Object DisplayName -eq 'All Staff' | Add-GkGroupMember -MemberId $userId -Confirm:$false

        Add a user to a group selected from a report.

    .EXAMPLE
        Add-GkGroupMember -GroupId $groupId -MemberId $userId -WhatIf

        Preview the change.

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
        Test-GkConnection -FunctionName 'Add-GkGroupMember' -Caller $PSCmdlet | Out-Null
        $encMember = [uri]::EscapeDataString($MemberId)
        $memberRef = "$script:GkGraphBaseUri/v1.0/directoryObjects/$encMember"
    }

    process {
        foreach ($gid in $GroupId) {
            if ([string]::IsNullOrWhiteSpace($gid)) { continue }
            if (-not $PSCmdlet.ShouldProcess($gid, "Add member $MemberId")) { continue }

            $enc = [uri]::EscapeDataString($gid)
            $outcome = 'Added'
            $errMsg = $null
            try {
                Invoke-GkGraphRequest -Method POST -Uri "/groups/$enc/members/`$ref" -Body @{ '@odata.id' = $memberRef } -CallerFunction 'Add-GkGroupMember' | Out-Null
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to add member to group '$gid': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName = 'PSGraphKit.GroupMemberResult'
                GroupId    = $gid
                MemberId   = $MemberId
                Action     = 'AddMember'
                Outcome    = $outcome
                Error      = $errMsg
            }
        }
    }
}
