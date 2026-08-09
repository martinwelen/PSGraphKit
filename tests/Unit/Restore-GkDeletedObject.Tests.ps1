Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Restore-GkDeletedObject' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.DeleteRestore.All') } }
            Mock Invoke-GkGraphRequest { @{ id = 'd1'; displayName = 'Ada Lovelace' } }
        }

        It 'validates the scope for the object type being restored' {
            Restore-GkDeletedObject -Id 'd1' -Type User -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter {
                $FunctionName -eq 'Restore-GkDeletedObject' -and $Variant -eq 'User'
            }
        }

        It 'validates a different scope for a different type' {
            Restore-GkDeletedObject -Id 'g1' -Type Group -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $Variant -eq 'Group' }
        }

        It 'POSTs to the restore action' {
            Restore-GkDeletedObject -Id 'd1' -Type User -Confirm:$false | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -eq '/directory/deletedItems/d1/restore'
            }
        }

        It 'reports the restored display name' {
            $r = Restore-GkDeletedObject -Id 'd1' -Type User -Confirm:$false
            $r.Outcome | Should -Be 'Restored'
            $r.DisplayName | Should -Be 'Ada Lovelace'
            $r.ObjectType | Should -Be 'User'
        }

        It 'accepts Get-GkDeletedItem output straight from the pipeline' {
            # Get-GkDeletedItem emits Id and ObjectType; ObjectType is aliased onto -Type.
            $items = @(
                [pscustomobject]@{ Id = 'd1'; ObjectType = 'User' }
                [pscustomobject]@{ Id = 'd2'; ObjectType = 'User' }
            )
            $r = @($items | Restore-GkDeletedObject -Confirm:$false)
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly
        }

        It 'validates each distinct type once, not once per object' {
            $items = 1..4 | ForEach-Object { [pscustomobject]@{ Id = "d$_"; ObjectType = 'User' } }
            $items | Restore-GkDeletedObject -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly
        }

        It 'makes no call under -WhatIf' {
            Restore-GkDeletedObject -Id 'd1' -Type User -WhatIf | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'warns and reports Failed on a UPN conflict' {
            Mock Invoke-GkGraphRequest { throw 'A conflicting object with userPrincipalName already exists' }
            $warnings = @()
            $r = Restore-GkDeletedObject -Id 'd1' -Type User -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            ($warnings -join ' ') | Should -Match 'conflicting'
        }

        It 'rejects a type Graph cannot restore through this action' {
            { Restore-GkDeletedObject -Id 'd1' -Type Device -Confirm:$false } | Should -Throw
        }
    }
}
