Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkLegacyAuthSignIn' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('AuditLog.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 's1'; createdDateTime = '2026-07-01T10:00:00Z'; userPrincipalName = 'ada@contoso.com'; appDisplayName = 'Office 365 Exchange Online'; clientAppUsed = 'IMAP4'; status = @{ errorCode = 0 } }
                    @{ id = 's2'; createdDateTime = '2026-07-01T10:05:00Z'; userPrincipalName = 'bob@contoso.com'; appDisplayName = 'Portal'; clientAppUsed = 'Browser'; status = @{ errorCode = 0 } }
                    @{ id = 's3'; createdDateTime = '2026-07-01T10:10:00Z'; userPrincipalName = 'cyd@contoso.com'; appDisplayName = 'SMTP'; clientAppUsed = 'Authenticated SMTP'; status = @{ errorCode = 50126; failureReason = 'bad creds' } }
                )
            }
        }

        It 'keeps only legacy-auth client sign-ins' {
            $r = Get-GkLegacyAuthSignIn
            $r.Count | Should -Be 2   # IMAP4 + Authenticated SMTP; Browser excluded
            $r.ClientApp | Should -Not -Contain 'Browser'
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.SignIn'
        }

        It '-SuccessfulOnly excludes failed sign-ins' {
            $r = Get-GkLegacyAuthSignIn -SuccessfulOnly
            $r.Count | Should -Be 1
            $r[0].UserPrincipalName | Should -Be 'ada@contoso.com'
        }

        It 'warns and returns nothing when the log is unavailable' {
            Mock Invoke-GkGraphRequest { throw 'P1/P2 required' }
            $warnings = @()
            Get-GkLegacyAuthSignIn -WarningVariable warnings -WarningAction SilentlyContinue | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'P1/P2'
        }
    }
}
