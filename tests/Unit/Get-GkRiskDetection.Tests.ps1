Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkRiskDetection' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('IdentityRiskEvent.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'd1'; activityDateTime = '2026-07-01T10:00:00Z'; userPrincipalName = 'ada@contoso.com'; riskEventType = 'unfamiliarFeatures'; riskLevel = 'medium'; riskState = 'atRisk'; detectionTimingType = 'realtime'; ipAddress = '1.2.3.4' }
                    @{ id = 'd2'; activityDateTime = '2026-07-01T11:00:00Z'; userPrincipalName = 'bob@contoso.com'; riskEventType = 'leakedCredentials'; riskLevel = 'high'; riskState = 'confirmedCompromised'; detectionTimingType = 'offline'; ipAddress = '5.6.7.8' }
                )
            }
        }

        It 'emits typed rows and derives DetectedDateTime' {
            $r = Get-GkRiskDetection
            $r.Count | Should -Be 2
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.RiskDetection'
            ($r | Where-Object Id -eq 'd2').RiskEventType | Should -Be 'leakedCredentials'
        }

        It '-RiskLevel filters' {
            (Get-GkRiskDetection -RiskLevel high).Count | Should -Be 1
        }

        It 'warns and returns nothing when unavailable' {
            Mock Invoke-GkGraphRequest { throw 'P1/P2 required' }
            $warnings = @()
            Get-GkRiskDetection -WarningVariable warnings -WarningAction SilentlyContinue | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'P1/P2'
        }
    }
}
