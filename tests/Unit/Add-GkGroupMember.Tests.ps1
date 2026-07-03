Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Add-GkGroupMember' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('GroupMember.ReadWrite.All') } }
            Mock Invoke-GkGraphRequest { $null }
        }

        It 'does NOT call Graph under -WhatIf' {
            Add-GkGroupMember -GroupId 'g1' -MemberId 'm1' -WhatIf | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'POSTs members/$ref with an @odata.id directory-object reference' {
            $r = Add-GkGroupMember -GroupId 'g1' -MemberId 'm1' -Confirm:$false
            $r.Outcome | Should -Be 'Added'
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.GroupMemberResult'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*/groups/g1/members/$ref' -and $Body['@odata.id'] -like '*/directoryObjects/m1'
            }
        }

        It 'warns and returns Failed on error (e.g. already a member)' {
            Mock Invoke-GkGraphRequest { throw 'already exist' }
            $warnings = @()
            $r = Add-GkGroupMember -GroupId 'g1' -MemberId 'm1' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            ($warnings -join ' ') | Should -Match 'g1'
        }

        It 'processes multiple groups from the pipeline (Id binds)' {
            $r = @([pscustomobject]@{ Id = 'g1' }, [pscustomobject]@{ Id = 'g2' }) | Add-GkGroupMember -MemberId 'm1' -Confirm:$false
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly
        }
    }
}
