Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Remove-GkGroupMember' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('GroupMember.ReadWrite.All') } }
            Mock Invoke-GkGraphRequest { $null }
        }

        It 'does NOT call Graph under -WhatIf' {
            Remove-GkGroupMember -GroupId 'g1' -MemberId 'm1' -WhatIf | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'DELETEs the member ref' {
            $r = Remove-GkGroupMember -GroupId 'g1' -MemberId 'm1' -Confirm:$false
            $r.Outcome | Should -Be 'Removed'
            $r.Action  | Should -Be 'RemoveMember'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and $Uri -like '*/groups/g1/members/m1/$ref'
            }
        }

        It 'warns and returns Failed on error' {
            Mock Invoke-GkGraphRequest { throw 'not found' }
            $warnings = @()
            $r = Remove-GkGroupMember -GroupId 'g1' -MemberId 'm1' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            ($warnings -join ' ') | Should -Match 'g1'
        }
    }
}
