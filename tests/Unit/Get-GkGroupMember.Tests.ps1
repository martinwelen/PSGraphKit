Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkGroupMember' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('GroupMember.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ '@odata.type' = '#microsoft.graph.user';  id = 'u1'; displayName = 'Ada'; userPrincipalName = 'ada@contoso.com'; accountEnabled = $true;  mail = 'ada@contoso.com' }
                    @{ '@odata.type' = '#microsoft.graph.group'; id = 'g2'; displayName = 'Nested'; mail = 'nested@contoso.com' }
                    @{ '@odata.type' = '#microsoft.graph.servicePrincipal'; id = 's1'; displayName = 'App SP' }
                )
            }
        }

        It 'validates the connection' {
            Get-GkGroupMember -GroupId 'g1' | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Get-GkGroupMember' }
        }

        It 'resolves @odata.type into a readable MemberType' {
            $r = @(Get-GkGroupMember -GroupId 'g1')
            $r.Count | Should -Be 3
            $r[0].MemberType | Should -Be 'User'
            $r[1].MemberType | Should -Be 'Group'
            $r[2].MemberType | Should -Be 'ServicePrincipal'
        }

        It 'stamps the group id on every row' {
            (Get-GkGroupMember -GroupId 'g1').GroupId | Should -Be @('g1', 'g1', 'g1')
        }

        It 'filters by -MemberType' {
            $r = @(Get-GkGroupMember -GroupId 'g1' -MemberType User)
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Ada'
        }

        It 'percent-encodes the group id in the request' {
            Get-GkGroupMember -GroupId 'a b/c' | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*a%20b%2Fc*' }
        }

        It 'passes -First through as MaxResult' {
            Get-GkGroupMember -GroupId 'g1' -First 10 | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $MaxResult -eq 10 }
        }

        It 'accepts several groups from the pipeline' {
            $r = @([pscustomobject]@{ Id = 'g1' }, [pscustomobject]@{ Id = 'g2' } | Get-GkGroupMember)
            $r.Count | Should -Be 6
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly
        }

        It 'warns and continues when one group fails' {
            Mock Invoke-GkGraphRequest { throw 'denied' }
            $warnings = @()
            $r = Get-GkGroupMember -GroupId 'g1' -WarningVariable warnings -WarningAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'g1'
        }

        It 'reports an unknown object type rather than dropping the row' {
            Mock Invoke-GkGraphRequest { @(@{ id = 'x1'; displayName = 'Mystery' }) }
            (Get-GkGroupMember -GroupId 'g1').MemberType | Should -Be 'Unknown'
        }
    }
}
