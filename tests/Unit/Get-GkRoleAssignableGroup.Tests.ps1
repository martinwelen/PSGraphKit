Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkRoleAssignableGroup' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Group.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*/owners*') {
                    if ($Uri -like '*rag-owned*') { return @(@{ id = 'o1'; displayName = 'Olga Owner' }) }
                    return @()   # ownerless
                }
                @(
                    @{ id = 'rag-owned'; displayName = 'Role Admins'; isAssignableToRole = $true; visibility = 'Private' }
                    @{ id = 'rag-orphan'; displayName = 'Orphan Privileged'; isAssignableToRole = $true; visibility = 'Private' }
                )
            }
        }

        It 'queries with isAssignableToRole filter and ConsistencyLevel, flags ownerless' {
            $r = Get-GkRoleAssignableGroup
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -ParameterFilter { $Uri -like '*isAssignableToRole eq true*' -and $Headers.ConsistencyLevel -eq 'eventual' }
            ($r | Where-Object DisplayName -eq 'Orphan Privileged').IsOwnerless | Should -BeTrue
            ($r | Where-Object DisplayName -eq 'Role Admins').Owners | Should -Contain 'Olga Owner'
        }

        It '-OwnerlessOnly returns only ownerless groups' {
            $r = Get-GkRoleAssignableGroup -OwnerlessOnly
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Orphan Privileged'
        }
    }
}
