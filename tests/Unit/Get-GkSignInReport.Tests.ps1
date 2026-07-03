Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkSignInReport' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('AuditLog.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 's1'; createdDateTime = '2026-07-01T10:00:00Z'; userPrincipalName = 'ada@contoso.com'; appDisplayName = 'Portal'; status = @{ errorCode = 0 }; riskLevelAggregated = 'none'; conditionalAccessStatus = 'success'; ipAddress = '1.2.3.4'; clientAppUsed = 'Browser' }
                    @{ id = 's2'; createdDateTime = '2026-07-01T11:00:00Z'; userPrincipalName = 'bob@contoso.com'; appDisplayName = 'Portal'; status = @{ errorCode = 50126; failureReason = 'Invalid credentials' }; riskLevelAggregated = 'high'; conditionalAccessStatus = 'failure'; ipAddress = '5.6.7.8'; clientAppUsed = 'Browser' }
                )
            }
        }

        It 'emits typed rows and derives Status from errorCode' {
            $r = Get-GkSignInReport
            $r.Count | Should -Be 2
            ($r | Where-Object Id -eq 's1').Status | Should -Be 'Success'
            ($r | Where-Object Id -eq 's2').Status | Should -Be 'Failure'
        }

        It 'builds a date filter from -Days' {
            Get-GkSignInReport -Days 3 | Out-Null
            Should -Invoke Invoke-GkGraphRequest -ParameterFilter { $Uri -like '*createdDateTime ge*' }
        }

        It '-FailedOnly returns only failures' {
            $r = Get-GkSignInReport -FailedOnly
            $r.Count | Should -Be 1
            $r[0].UserPrincipalName | Should -Be 'bob@contoso.com'
        }

        It '-RiskyOnly excludes none/hidden risk' {
            (Get-GkSignInReport -RiskyOnly).Count | Should -Be 1
        }

        It 'warns and returns nothing when the log is unavailable' {
            Mock Invoke-GkGraphRequest { throw 'P1/P2 required' }
            $warnings = @()
            $r = Get-GkSignInReport -WarningVariable warnings -WarningAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'P1/P2'
        }
    }
}
