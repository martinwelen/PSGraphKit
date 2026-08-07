function Remove-GkAdminRoleAssignment {
    <#
    .SYNOPSIS
        Remove a directory role assignment — direct active, PIM-eligible, or PIM active.

    .DESCRIPTION
        Removes the assignment using the correct path for its kind (as reported by
        Get-GkAdminRoleAssignment, which this cmdlet is designed to accept from the pipeline):
          * Active     DELETE /roleManagement/directory/roleAssignments/{AssignmentId}
          * Eligible   POST /roleManagement/directory/roleEligibilityScheduleRequests (action=adminRemove)
          * TimeBound  POST /roleManagement/directory/roleAssignmentScheduleRequests (action=adminRemove)

        State-changing: supports -WhatIf / -Confirm and prompts by default. Yields a
        PSGraphKit.RoleRemovalResult per assignment; failures warn and continue. Graph refuses to
        remove the caller's own Global Administrator assignment. Requires
        RoleManagement.ReadWrite.Directory plus the Privileged Role Administrator role.

    .PARAMETER AssignmentKind
        Active, Eligible, or TimeBound (bound from Get-GkAdminRoleAssignment output).

    .PARAMETER AssignmentId
        The roleAssignment id (required for Active removals).

    .PARAMETER PrincipalId
        Principal id (required for PIM Eligible/TimeBound removals).

    .PARAMETER RoleDefinitionId
        Role definition id (required for PIM Eligible/TimeBound removals).

    .PARAMETER Scope
        Directory scope id ('/' = tenant). Defaults to '/'.

    .PARAMETER RoleName
        Role display name, used only for confirmation/output messages.

    .PARAMETER Justification
        Justification recorded on PIM removal requests.

    .EXAMPLE
        Get-GkAdminRoleAssignment -AssignmentKind Eligible -RoleName '*Administrator*' |
            Remove-GkAdminRoleAssignment -WhatIf

        Preview removing every eligible *Administrator* assignment.

    .EXAMPLE
        Get-GkAdminRoleAssignment | Where-Object PrincipalName -eq 'Ada Admin' |
            Remove-GkAdminRoleAssignment -Confirm:$false

        Remove all of one principal's assignments.

    .EXAMPLE
        Remove-GkAdminRoleAssignment -AssignmentKind Active -AssignmentId $id -RoleName 'Helpdesk Administrator'

        Remove one active assignment by id (prompts for confirmation).

    .OUTPUTS
        PSGraphKit.RoleRemovalResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.RoleRemovalResult')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet('Active', 'Eligible', 'TimeBound')]
        [string] $AssignmentKind,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $AssignmentId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $PrincipalId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $RoleDefinitionId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Scope,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $RoleName,

        [string] $Justification = 'Removed via PSGraphKit'
    )

    begin {
        Test-GkConnection -FunctionName 'Remove-GkAdminRoleAssignment' -Caller $PSCmdlet | Out-Null
    }

    process {
        # Include a unique identifier so a bulk -Confirm run distinguishes each assignment being removed.
        $who = if ($PrincipalId) { "principal $PrincipalId" } elseif ($AssignmentId) { "assignment $AssignmentId" } else { 'assignment' }
        $target = if ($RoleName) { "$RoleName [$AssignmentKind] — $who" } else { "$AssignmentKind — $who" }
        if (-not $PSCmdlet.ShouldProcess($target, 'Remove role assignment')) { return }

        $dirScope = if ($Scope) { $Scope } else { '/' }
        $outcome = 'Removed'
        $errMsg = $null
        try {
            switch ($AssignmentKind) {
                'Active' {
                    if (-not $AssignmentId) { throw 'AssignmentId is required to remove an active assignment.' }
                    Invoke-GkGraphRequest -Method DELETE -CallerFunction 'Remove-GkAdminRoleAssignment' `
                        -Uri "/roleManagement/directory/roleAssignments/$([uri]::EscapeDataString($AssignmentId))" | Out-Null
                }
                'Eligible' {
                    if (-not $PrincipalId -or -not $RoleDefinitionId) { throw 'PrincipalId and RoleDefinitionId are required to remove a PIM eligible assignment.' }
                    Invoke-GkGraphRequest -Method POST -CallerFunction 'Remove-GkAdminRoleAssignment' `
                        -Uri '/roleManagement/directory/roleEligibilityScheduleRequests' `
                        -Body @{ action = 'adminRemove'; principalId = $PrincipalId; roleDefinitionId = $RoleDefinitionId; directoryScopeId = $dirScope; justification = $Justification } | Out-Null
                }
                'TimeBound' {
                    if (-not $PrincipalId -or -not $RoleDefinitionId) { throw 'PrincipalId and RoleDefinitionId are required to remove a PIM active assignment.' }
                    Invoke-GkGraphRequest -Method POST -CallerFunction 'Remove-GkAdminRoleAssignment' `
                        -Uri '/roleManagement/directory/roleAssignmentScheduleRequests' `
                        -Body @{ action = 'adminRemove'; principalId = $PrincipalId; roleDefinitionId = $RoleDefinitionId; directoryScopeId = $dirScope; justification = $Justification } | Out-Null
                }
            }
        }
        catch {
            $outcome = 'Failed'
            $errMsg = $_.Exception.Message
            Write-Warning "Failed to remove $target : $errMsg"
        }

        [pscustomobject]@{
            PSTypeName     = 'PSGraphKit.RoleRemovalResult'
            RoleName       = $RoleName
            AssignmentKind = $AssignmentKind
            PrincipalId    = $PrincipalId
            AssignmentId   = $AssignmentId
            Scope          = $dirScope
            Outcome        = $outcome
            Error          = $errMsg
        }
    }
}
