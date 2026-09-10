Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Remove-GkAdminRoleAssignment' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('RoleManagement.ReadWrite.Directory') } }
            Mock Invoke-GkGraphRequest { $null }
        }

        It 'validates the connection' {
            Remove-GkAdminRoleAssignment -AssignmentKind Active -AssignmentId 'ra1' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Remove-GkAdminRoleAssignment' }
        }

        It 'DELETEs a direct active assignment by id' {
            $r = Remove-GkAdminRoleAssignment -AssignmentKind Active -AssignmentId 'ra1' -RoleName 'Global Administrator' -Confirm:$false
            $r.Outcome | Should -Be 'Removed'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and $Uri -like '*/roleAssignments/ra1'
            }
        }

        It 'POSTs adminRemove for an eligible (PIM) assignment' {
            $r = Remove-GkAdminRoleAssignment -AssignmentKind Eligible -PrincipalId 'p1' -RoleDefinitionId 'rd1' -Scope '/' -Confirm:$false
            $r.Outcome | Should -Be 'Removed'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*roleEligibilityScheduleRequests' -and
                $Body.action -eq 'adminRemove' -and $Body.principalId -eq 'p1' -and $Body.roleDefinitionId -eq 'rd1'
            }
        }

        It 'POSTs adminRemove for a time-bound (PIM active) assignment' {
            Remove-GkAdminRoleAssignment -AssignmentKind TimeBound -PrincipalId 'p1' -RoleDefinitionId 'rd1' -Confirm:$false | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*roleAssignmentScheduleRequests' -and $Body.action -eq 'adminRemove'
            }
        }

        It 'fails an Active removal that lacks an AssignmentId' {
            $r = Remove-GkAdminRoleAssignment -AssignmentKind Active -RoleName 'x' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            $r.Error   | Should -Match 'AssignmentId'
            # The result object carries the failure, but a bulk pipeline run is read on screen, so
            # the warning is the part the operator actually sees. Pin it too.
            $warnings | Should -Not -BeNullOrEmpty
            "$warnings" | Should -Match 'AssignmentId'
        }

        It 'makes no call under -WhatIf' {
            Remove-GkAdminRoleAssignment -AssignmentKind Active -AssignmentId 'ra1' -WhatIf | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'binds pipeline input shaped like Get-GkAdminRoleAssignment output' {
            $assignments = @(
                [pscustomobject]@{ AssignmentKind = 'Active'; AssignmentId = 'ra1'; RoleName = 'GA'; PrincipalId = 'p1' }
                [pscustomobject]@{ AssignmentKind = 'Eligible'; PrincipalId = 'p2'; RoleDefinitionId = 'rd2'; Scope = '/'; RoleName = 'UA' }
            )
            $r = $assignments | Remove-GkAdminRoleAssignment -Confirm:$false
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Method -eq 'DELETE' }
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*roleEligibilityScheduleRequests' }
        }
    }
}
