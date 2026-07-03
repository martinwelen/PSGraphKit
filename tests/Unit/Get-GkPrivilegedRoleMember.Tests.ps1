Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkPrivilegedRoleMember' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('RoleManagement.Read.All') } }
            Mock Get-GkAdminRoleAssignment {
                @(
                    [pscustomobject]@{ RoleName = 'Global Administrator'; AssignmentKind = 'Active';   PrincipalName = 'Ada';   PrincipalType = 'User'; PrincipalUpn = 'ada@c.com'; PrincipalId = 'p1' }
                    [pscustomobject]@{ RoleName = 'Global Administrator'; AssignmentKind = 'Eligible'; PrincipalName = 'Eli';   PrincipalType = 'User'; PrincipalUpn = 'eli@c.com'; PrincipalId = 'p2' }
                    [pscustomobject]@{ RoleName = 'Directory Readers';    AssignmentKind = 'Active';   PrincipalName = 'Ron';   PrincipalType = 'User'; PrincipalUpn = 'ron@c.com'; PrincipalId = 'p3' }
                    [pscustomobject]@{ RoleName = 'User Administrator';   AssignmentKind = 'Active';   PrincipalName = 'Uma';   PrincipalType = 'User'; PrincipalUpn = 'uma@c.com'; PrincipalId = 'p4' }
                )
            }
        }

        It 'keeps only privileged roles and flags permanent assignments' {
            $r = Get-GkPrivilegedRoleMember
            $r.Count | Should -Be 3   # 2x GA + User Admin; Directory Readers is not privileged
            $r.RoleName | Should -Not -Contain 'Directory Readers'
            ($r | Where-Object PrincipalName -eq 'Ada').IsPermanent | Should -BeTrue
            ($r | Where-Object PrincipalName -eq 'Eli').IsPermanent | Should -BeFalse
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.PrivilegedRoleMember'
        }

        It '-PermanentOnly returns only standing (non-PIM) assignments' {
            $r = Get-GkPrivilegedRoleMember -PermanentOnly
            $r.Count | Should -Be 2   # Ada (GA) + Uma (User Admin); Eli is Eligible
            $r.AssignmentKind | Should -Not -Contain 'Eligible'
        }
    }
}
