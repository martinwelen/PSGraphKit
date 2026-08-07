Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkServiceHealth' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('ServiceHealth.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*healthOverviews*') {
                    return @(
                        @{ id = 'Exchange'; service = 'Exchange Online'; status = 'serviceOperational' }
                        @{ id = 'SharePoint'; service = 'SharePoint Online'; status = 'serviceDegradation' }
                    )
                }
                return @(
                    @{ id = 'SP12345'; service = 'SharePoint Online'; title = 'Users cannot upload'; isResolved = $false }
                    @{ id = 'SP99999'; service = 'SharePoint Online'; title = 'Already fixed'; isResolved = $true }
                )
            }
        }

        It 'validates the connection' {
            Get-GkServiceHealth | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Get-GkServiceHealth' }
        }

        It 'derives IsHealthy from the operational status' {
            $r = @(Get-GkServiceHealth)
            $r[0].IsHealthy | Should -BeTrue
            $r[1].IsHealthy | Should -BeFalse
        }

        It 'makes no issues call unless -IncludeIssue is given' {
            Get-GkServiceHealth | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*issues*' }
        }

        It 'reads issues exactly once for the whole run, not once per service' {
            Get-GkServiceHealth -IncludeIssue | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*issues*' }
        }

        It 'attaches only unresolved issues to their service' {
            $r = @(Get-GkServiceHealth -IncludeIssue)
            $r[0].OpenIssueCount | Should -Be 0
            $r[1].OpenIssueCount | Should -Be 1
            ($r[1].OpenIssues -join ' ') | Should -Match 'SP12345'
            ($r[1].OpenIssues -join ' ') | Should -Not -Match 'SP99999'
        }

        It 'returns only unhealthy services with -UnhealthyOnly' {
            $r = @(Get-GkServiceHealth -UnhealthyOnly)
            $r.Count | Should -Be 1
            $r[0].Service | Should -Be 'SharePoint Online'
        }

        It 'matches -Service as a substring' {
            $r = @(Get-GkServiceHealth -Service 'Exchange')
            $r.Count | Should -Be 1
        }

        It 'still reports status when the issues call fails' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*issues*') { throw 'denied' }
                @(@{ id = 'Exchange'; service = 'Exchange Online'; status = 'serviceDegradation' })
            }
            $warnings = @()
            $r = @(Get-GkServiceHealth -IncludeIssue -WarningVariable warnings -WarningAction SilentlyContinue)
            $r.Count | Should -Be 1
            $r[0].OpenIssueCount | Should -Be 0
            ($warnings -join ' ') | Should -Match 'issues'
        }
    }
}
