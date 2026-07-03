Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Revoke-GkUserSession' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.RevokeSessions.All') } }
            Mock Invoke-GkGraphRequest { $null }   # 204 No Content
        }

        It 'validates the connection before acting' {
            Revoke-GkUserSession -UserId 'ada@contoso.com' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Revoke-GkUserSession' }
        }

        It 'does NOT call Graph under -WhatIf and emits nothing' {
            $out = Revoke-GkUserSession -UserId 'ada@contoso.com' -WhatIf
            $out | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'POSTs revokeSignInSessions and returns a Revoked result' {
            $r = Revoke-GkUserSession -UserId 'ada@contoso.com' -Confirm:$false
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.SessionRevokeResult'
            $r.Outcome | Should -Be 'Revoked'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*/revokeSignInSessions'
            }
        }

        It 'percent-encodes a guest UPN so # is not a URL fragment' {
            Revoke-GkUserSession -UserId 'bob_x.com#EXT#@contoso.onmicrosoft.com' -Confirm:$false | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -notlike '*#*' -and $Uri -like '*%23EXT%23*'
            }
        }

        It 'warns and returns a Failed result when the call errors' {
            Mock Invoke-GkGraphRequest { throw 'denied' }
            $warnings = @()
            $r = Revoke-GkUserSession -UserId 'ada@contoso.com' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            $r.Error   | Should -Match 'denied'
            ($warnings -join ' ') | Should -Match 'ada@contoso.com'
        }

        It 'processes multiple users from the pipeline' {
            $r = 'a@contoso.com', 'b@contoso.com' | Revoke-GkUserSession -Confirm:$false
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly
        }
    }
}
