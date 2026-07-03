Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Disable-GkStaleUser' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.EnableDisableAccount.All') } }
            Mock Invoke-GkGraphRequest { $null }   # 204 No Content
        }

        It 'validates the connection before acting' {
            Disable-GkStaleUser -UserId 'ada@contoso.com' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Disable-GkStaleUser' }
        }

        It 'does NOT call Graph under -WhatIf and emits nothing' {
            $out = Disable-GkStaleUser -UserId 'ada@contoso.com' -WhatIf
            $out | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'PATCHes accountEnabled=false and returns a Disabled result' {
            $r = Disable-GkStaleUser -UserId 'ada@contoso.com' -Confirm:$false
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.UserDisableResult'
            $r.Outcome | Should -Be 'Disabled'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PATCH' -and $Uri -like '*/users/*' -and $Body.accountEnabled -eq $false
            }
        }

        It 'percent-encodes a guest UPN' {
            Disable-GkStaleUser -UserId 'bob_x.com#EXT#@contoso.onmicrosoft.com' -Confirm:$false | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -notlike '*#*' -and $Uri -like '*%23EXT%23*'
            }
        }

        It 'warns and returns a Failed result when the call errors' {
            Mock Invoke-GkGraphRequest { throw 'denied' }
            $warnings = @()
            $r = Disable-GkStaleUser -UserId 'ada@contoso.com' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            ($warnings -join ' ') | Should -Match 'ada@contoso.com'
        }

        It 'processes multiple users from the pipeline' {
            $r = 'a@contoso.com', 'b@contoso.com' | Disable-GkStaleUser -Confirm:$false
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly
        }
    }
}
