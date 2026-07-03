Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkInactiveApp' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('AuditLog.Read.All', 'Application.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*servicePrincipalSignInActivities*') {
                    return @(
                        @{ id = 'a1'; appId = 'app-old';   delegatedClientSignInActivity = @{ lastSignInDateTime = '2023-01-01T00:00:00Z' } }
                        @{ id = 'a2'; appId = 'app-never' }
                    )
                }
                if ($Uri -like '*servicePrincipals?*') {
                    return @(@{ appId = 'app-old'; displayName = 'Old App' }, @{ appId = 'app-never'; displayName = 'Never App' })
                }
                @()
            }
        }

        It 'uses the beta endpoint and resolves app names' {
            $r = Get-GkInactiveApp
            Should -Invoke Invoke-GkGraphRequest -ParameterFilter { $Uri -like '*servicePrincipalSignInActivities*' -and $ApiVersion -eq 'beta' }
            ($r | Where-Object AppId -eq 'app-old').AppDisplayName | Should -Be 'Old App'
        }

        It 'computes staleness and never-active' {
            $r = Get-GkInactiveApp
            ($r | Where-Object AppId -eq 'app-old').IsStale     | Should -BeTrue
            ($r | Where-Object AppId -eq 'app-never').NeverActive | Should -BeTrue
        }

        It '-StaleOnly excludes recently active apps' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*servicePrincipalSignInActivities*') {
                    return @(
                        @{ id = 'r'; appId = 'recent'; delegatedClientSignInActivity = @{ lastSignInDateTime = ([datetime]::UtcNow.AddDays(-2).ToString('o')) } }
                        @{ id = 's'; appId = 'stale';  delegatedClientSignInActivity = @{ lastSignInDateTime = ([datetime]::UtcNow.AddDays(-200).ToString('o')) } }
                    )
                }
                if ($Uri -like '*servicePrincipals?*') { return @() }
                @()
            }
            $r = Get-GkInactiveApp -StaleOnly -InactiveDays 90
            $r.Count | Should -Be 1
            $r[0].AppId | Should -Be 'stale'
        }

        It 'warns and returns nothing when the beta report is unavailable' {
            Mock Invoke-GkGraphRequest { if ($Uri -like '*servicePrincipalSignInActivities*') { throw 'not available' } }
            $warnings = @()
            Get-GkInactiveApp -WarningVariable warnings -WarningAction SilentlyContinue | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'beta'
        }
    }
}
