Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkRiskyUser' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('IdentityRiskyUser.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'u1'; userPrincipalName = 'ada@contoso.com'; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'; riskLastUpdatedDateTime = '2026-07-01T00:00:00Z' }
                    @{ id = 'u2'; userPrincipalName = 'bob@contoso.com'; riskLevel = 'low'; riskState = 'remediated'; riskDetail = 'userPerformedSecuredPasswordReset'; riskLastUpdatedDateTime = '2026-06-01T00:00:00Z' }
                )
            }
        }

        It 'emits typed rows' {
            $r = Get-GkRiskyUser
            $r.Count | Should -Be 2
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.RiskyUser'
        }

        It '-RiskLevel filters' {
            (Get-GkRiskyUser -RiskLevel high).Count | Should -Be 1
        }

        It '-AtRiskOnly excludes remediated/dismissed' {
            $r = Get-GkRiskyUser -AtRiskOnly
            $r.Count | Should -Be 1
            $r[0].UserPrincipalName | Should -Be 'ada@contoso.com'
        }

        It '-First is forwarded to the pagination cap (MaxResult)' {
            Get-GkRiskyUser -First 100 | Out-Null
            Should -Invoke Invoke-GkGraphRequest -ParameterFilter { $MaxResult -eq 100 }
        }

        It 'warns and returns nothing when unavailable (no P2)' {
            Mock Invoke-GkGraphRequest { throw 'requires P2' }
            $warnings = @()
            $r = Get-GkRiskyUser -WarningVariable warnings -WarningAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'P2'
        }
    }
}
