Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkAdminRoleAssignment' {

        BeforeAll {
            $fx = Join-Path $PSScriptRoot '..' 'fixtures'
            $script:ActiveValue    = (Get-Content (Join-Path $fx 'roleAssignments-active.json')            -Raw | ConvertFrom-Json -AsHashtable)['value']
            $script:EligibleValue  = (Get-Content (Join-Path $fx 'roleEligibility-instances.json')          -Raw | ConvertFrom-Json -AsHashtable)['value']
            $script:TimeBoundValue = (Get-Content (Join-Path $fx 'roleAssignmentSchedule-instances.json')   -Raw | ConvertFrom-Json -AsHashtable)['value']
            $script:RoleDefValue   = (Get-Content (Join-Path $fx 'roleDefinitions.json')                    -Raw | ConvertFrom-Json -AsHashtable)['value']
        }

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('RoleManagement.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*roleDefinitions*')                    { return $script:RoleDefValue }
                if ($Uri -like '*roleEligibilityScheduleInstances*')   { return $script:EligibleValue }
                if ($Uri -like '*roleAssignmentScheduleInstances*')    { return $script:TimeBoundValue }
                if ($Uri -like '*roleAssignments*')                    { return $script:ActiveValue }
                @()
            }
        }

        It 'returns all three assignment kinds by default' {
            $r = Get-GkAdminRoleAssignment
            $r.Count | Should -Be 3
            ($r.AssignmentKind | Sort-Object -Unique) | Should -Be @('Active', 'Eligible', 'TimeBound')
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.AdminRoleAssignment'
        }

        It 'resolves principal name, type, and role name' {
            $active = Get-GkAdminRoleAssignment -AssignmentKind Active
            $active.Count             | Should -Be 1
            $active[0].RoleName       | Should -Be 'Global Administrator'
            $active[0].PrincipalName  | Should -Be 'Ada Admin'
            $active[0].PrincipalUpn   | Should -Be 'ada@contoso.com'
            $active[0].PrincipalType  | Should -Be 'User'
            $active[0].IsTenantScope  | Should -BeTrue
        }

        It 'maps group principals and AU scope for time-bound assignments' {
            $tb = Get-GkAdminRoleAssignment -AssignmentKind TimeBound
            $tb[0].PrincipalType  | Should -Be 'Group'
            $tb[0].AssignmentType | Should -Be 'Activated'
            $tb[0].IsTenantScope  | Should -BeFalse
            $tb[0].Scope          | Should -Be '/administrativeUnits/au1'
            $tb[0].EndDateTime    | Should -Be ([datetime]::new(2026, 7, 1, 0, 0, 0, [System.DateTimeKind]::Utc))
        }

        It 'filters by role name (client-side wildcard)' {
            $r = Get-GkAdminRoleAssignment -RoleName '*User*'
            $r.Count | Should -Be 1
            $r[0].RoleName | Should -Be 'User Administrator'
        }

        It 'expands only principal and resolves role names via roleDefinitions (Graph allows one $expand)' {
            Get-GkAdminRoleAssignment -AssignmentKind Active | Out-Null
            # roleDefinitions must be fetched for the name map
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*roleDefinitions*' }
            # the active assignments call must NOT try to expand roleDefinition as well
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -like '*roleAssignments*' -and $Uri -notlike '*Schedule*' -and $Uri -notlike '*roleDefinition*'
            }
        }

        It 'resolves role names referenced by templateId (not just id)' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*roleDefinitions*') {
                    return @(@{ id = 'def-abc'; templateId = 'tmpl-xyz'; displayName = 'Custom Reader' })
                }
                if ($Uri -like '*ScheduleInstances*') { return @() }
                if ($Uri -like '*roleAssignments*') {
                    return @(@{ id = 'a1'; principalId = 'p1'; roleDefinitionId = 'tmpl-xyz'; directoryScopeId = '/'
                                principal = @{ '@odata.type' = '#microsoft.graph.user'; displayName = 'Someone' } })
                }
                @()
            }
            $r = Get-GkAdminRoleAssignment -AssignmentKind Active
            $r.Count | Should -Be 1
            $r[0].RoleName | Should -Be 'Custom Reader'
        }

        It 'only queries the requested kind' {
            Get-GkAdminRoleAssignment -AssignmentKind Active | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*Eligibility*' }
        }

        It 'warns and continues when PIM endpoints are unavailable (no P2)' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*roleDefinitions*') { return $script:RoleDefValue }
                # Both PIM endpoints contain 'ScheduleInstances'; the active endpoint does not.
                if ($Uri -like '*ScheduleInstances*') { throw 'The tenant needs a Microsoft Entra ID P2 license' }
                return $script:ActiveValue
            }
            $warnings = @()
            $r = Get-GkAdminRoleAssignment -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Count | Should -Be 1
            $r[0].AssignmentKind | Should -Be 'Active'
            ($warnings -join ' ') | Should -Match 'P2'
        }

        It 'adds a timestamp with -AsReport' {
            (Get-GkAdminRoleAssignment -AssignmentKind Active -AsReport)[0].ReportGeneratedUtc | Should -BeOfType ([datetime])
        }
    }
}
