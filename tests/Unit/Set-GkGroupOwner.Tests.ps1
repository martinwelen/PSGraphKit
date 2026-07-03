Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Set-GkGroupOwner' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Group.ReadWrite.All') } }
            Mock Invoke-GkGraphRequest { $null }   # 204 No Content
        }

        It 'validates the connection before acting' {
            Set-GkGroupOwner -GroupId 'g1' -OwnerId 'o1' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Set-GkGroupOwner' }
        }

        It 'does NOT call Graph under -WhatIf' {
            Set-GkGroupOwner -GroupId 'g1' -OwnerId 'o1' -WhatIf | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'POSTs owners/$ref with an @odata.id directory-object reference' {
            $r = Set-GkGroupOwner -GroupId 'g1' -OwnerId 'o1' -Confirm:$false
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.GroupOwnerResult'
            $r.Outcome | Should -Be 'OwnerAdded'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*/groups/g1/owners/$ref' -and
                $Body['@odata.id'] -like '*/directoryObjects/o1'
            }
        }

        It 'warns and returns Failed when the call errors (e.g. already an owner)' {
            Mock Invoke-GkGraphRequest { throw 'One or more added object references already exist' }
            $warnings = @()
            $r = Set-GkGroupOwner -GroupId 'g1' -OwnerId 'o1' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            ($warnings -join ' ') | Should -Match 'g1'
        }

        It 'processes multiple groups from the pipeline (Id property binds)' {
            $groups = @([pscustomobject]@{ Id = 'g1' }, [pscustomobject]@{ Id = 'g2' })
            $r = $groups | Set-GkGroupOwner -OwnerId 'o1' -Confirm:$false
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly
        }
    }
}
