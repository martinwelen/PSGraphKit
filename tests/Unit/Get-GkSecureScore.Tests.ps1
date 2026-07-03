Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkSecureScore' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('SecurityEvents.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(@{ currentScore = 42; maxScore = 60; activeUserCount = 100; licensedUserCount = 120; createdDateTime = '2026-07-01T00:00:00Z'
                     controlScores = @(
                         @{ controlName = 'MFARegistrationV2'; controlCategory = 'Identity'; score = 5; description = 'Register MFA' }
                         @{ controlName = 'BlockLegacyAuth'; controlCategory = 'Identity'; score = 0; description = 'Block legacy' }
                     ) })
            }
        }

        It 'returns the latest score summary with a computed percentage' {
            $r = Get-GkSecureScore
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.SecureScore'
            $r.CurrentScore  | Should -Be 42
            $r.MaxScore      | Should -Be 60
            $r.Percentage    | Should -Be 70
            $r.ControlCount  | Should -Be 2
        }

        It '-IncludeControls returns per-control rows' {
            $r = Get-GkSecureScore -IncludeControls
            $r.Count | Should -Be 2
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.SecureScoreControl'
            ($r | Where-Object ControlName -eq 'BlockLegacyAuth').Score | Should -Be 0
        }

        It 'warns when no score data is returned' {
            Mock Invoke-GkGraphRequest { @() }
            $warnings = @()
            $r = Get-GkSecureScore -WarningVariable warnings -WarningAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'Secure Score'
        }
    }
}
