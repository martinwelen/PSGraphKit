Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Reset-GkUserPassword' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User-PasswordProfile.ReadWrite.All') } }
            Mock Invoke-GkGraphRequest { $null }   # 204 No Content
        }

        It 'validates the connection' {
            Reset-GkUserPassword -UserId 'ada@contoso.com' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Reset-GkUserPassword' }
        }

        It 'PATCHes a passwordProfile and forces a change by default' {
            $r = Reset-GkUserPassword -UserId 'ada@contoso.com' -Confirm:$false
            $r.Outcome | Should -Be 'Reset'
            $r.ForceChangeNextSignIn | Should -BeTrue
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PATCH' -and $Body.passwordProfile.forceChangePasswordNextSignIn -eq $true
            }
        }

        It 'returns the generated password on the result' {
            $r = Reset-GkUserPassword -UserId 'ada@contoso.com' -Confirm:$false
            $r.Password | Should -Not -BeNullOrEmpty
            $r.Password.Length | Should -Be 20
        }

        It 'sends the password it reports' {
            $sent = $null
            Mock Invoke-GkGraphRequest { $script:sent = $Body.passwordProfile.password; $null }
            $r = Reset-GkUserPassword -UserId 'ada@contoso.com' -Confirm:$false
            $r.Password | Should -Be $script:sent
        }

        It 'generates a distinct password per user in a bulk reset' {
            $r = @('a@contoso.com', 'b@contoso.com', 'c@contoso.com' | Reset-GkUserPassword -Confirm:$false)
            $r.Count | Should -Be 3
            ($r.Password | Select-Object -Unique).Count | Should -Be 3
        }

        It 'uses an explicit -NewPassword when given' {
            $secure = ConvertTo-SecureString 'Correct-Horse-9' -AsPlainText -Force
            $r = Reset-GkUserPassword -UserId 'ada@contoso.com' -NewPassword $secure -Confirm:$false
            $r.Password | Should -Be 'Correct-Horse-9'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Body.passwordProfile.password -eq 'Correct-Horse-9'
            }
        }

        It 'reuses the supplied password across every user, unlike a generated one' {
            $secure = ConvertTo-SecureString 'Correct-Horse-9' -AsPlainText -Force
            $r = @('a@contoso.com', 'b@contoso.com' | Reset-GkUserPassword -NewPassword $secure -Confirm:$false)
            ($r.Password | Select-Object -Unique) | Should -Be 'Correct-Horse-9'
        }

        It 'skips the forced change with -NoForceChange' {
            $r = Reset-GkUserPassword -UserId 'ada@contoso.com' -NoForceChange -Confirm:$false
            $r.ForceChangeNextSignIn | Should -BeFalse
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Body.passwordProfile.forceChangePasswordNextSignIn -eq $false
            }
        }

        It 'makes no call under -WhatIf' {
            Reset-GkUserPassword -UserId 'ada@contoso.com' -WhatIf | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'clears the password and warns when the reset fails' {
            Mock Invoke-GkGraphRequest { throw 'denied' }
            $warnings = @()
            $r = Reset-GkUserPassword -UserId 'ada@contoso.com' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome  | Should -Be 'Failed'
            $r.Password | Should -BeNullOrEmpty -Because 'a password that was never set must not be reported as if it were'
            ($warnings -join ' ') | Should -Match 'ada@contoso.com'
        }

        It 'percent-encodes a guest UPN' {
            Reset-GkUserPassword -UserId 'bob_x.com#EXT#@contoso.onmicrosoft.com' -Confirm:$false | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -notlike '*#*' -and $Uri -like '*%23EXT%23*' }
        }
    }

    Describe 'Secrets stay out of the default view' {

        # The module's convention: a secret rides on the result object so it can be captured
        # deliberately, but never appears in the formatted table.
        $cases = @(
            @{ TypeName = 'PSGraphKit.PasswordResetResult';       Secret = 'Password' }
            @{ TypeName = 'PSGraphKit.TemporaryAccessPassResult'; Secret = 'TemporaryAccessPass' }
            @{ TypeName = 'PSGraphKit.LapsCredential';            Secret = 'Password' }
            @{ TypeName = 'PSGraphKit.AppCredentialResult';       Secret = 'SecretText' }
        )

        It '<TypeName> does not display <Secret>' -TestCases $cases {
            param($TypeName, $Secret)
            $path = Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'Formats' 'PSGraphKit.Format.ps1xml'
            [xml]$x = Get-Content $path -Raw
            $view = $x.Configuration.ViewDefinitions.View | Where-Object { $_.Name -eq $TypeName }
            $view | Should -Not -BeNullOrEmpty
            $rendered = $view.OuterXml
            $rendered | Should -Not -Match ">$Secret<"
        }
    }
}
