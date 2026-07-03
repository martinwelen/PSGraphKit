Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Remove-GkConsentGrant' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('DelegatedPermissionGrant.ReadWrite.All') } }
            Mock Invoke-GkGraphRequest { $null }
        }

        It 'does NOT call Graph under -WhatIf' {
            Remove-GkConsentGrant -GrantId 'grant-1' -WhatIf | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'DELETEs the grant and returns a Revoked result' {
            $r = Remove-GkConsentGrant -GrantId 'grant-1' -Confirm:$false
            $r.Outcome | Should -Be 'Revoked'
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.ConsentGrantRemovalResult'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Method -eq 'DELETE' -and $Uri -like '*/oauth2PermissionGrants/grant-1' }
        }

        It 'warns and returns Failed on error' {
            Mock Invoke-GkGraphRequest { throw 'denied' }
            $warnings = @()
            $r = Remove-GkConsentGrant -GrantId 'grant-1' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            ($warnings -join ' ') | Should -Match 'grant-1'
        }

        It 'processes multiple grant ids from the pipeline' {
            $r = 'g1', 'g2' | Remove-GkConsentGrant -Confirm:$false
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly
        }
    }
}
