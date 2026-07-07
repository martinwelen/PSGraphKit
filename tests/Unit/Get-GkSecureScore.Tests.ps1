Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkSecureScore' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('SecurityEvents.Read.All') } }

            # Mock the low-level seam so the REAL Invoke-GkGraphRequest runs — including pagination and its
            # single-object (non-unrolling) return contract. Mocking Invoke-GkGraphRequest itself with a plain
            # array (as an earlier version did) hid a real bug: secureScores?$top=1 returns one item PLUS a
            # nextLink, so the live result is a multi-item array handed back as ONE object, which the old
            # @(...) | Select-Object -First 1 consumer turned into the whole array (nulling every field).
            $script:call = 0
            Mock Invoke-GkRawGraphCall {
                $script:call++
                if ($script:call -eq 1) {
                    [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{
                        value             = @(@{ currentScore = 42; maxScore = 60; activeUserCount = 100; licensedUserCount = 120
                                                 createdDateTime = '2026-07-01T00:00:00Z'
                                                 controlScores = @(
                                                     @{ controlName = 'MFARegistrationV2'; controlCategory = 'Identity'; score = 5; description = 'Register MFA' }
                                                     @{ controlName = 'BlockLegacyAuth'; controlCategory = 'Identity'; score = 0; description = 'Block legacy' }
                                                 ) })
                        '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/security/secureScores?$top=1&$skiptoken=x'
                    } }
                }
                else {
                    [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{
                        value = @(@{ currentScore = 30; maxScore = 60; createdDateTime = '2026-06-30T00:00:00Z'; controlScores = @() })
                    } }
                }
            }
        }

        It 'returns the latest score summary with a computed percentage' {
            $r = Get-GkSecureScore
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.SecureScore'
            $r.CurrentScore  | Should -Be 42
            $r.MaxScore      | Should -Be 60
            $r.Percentage    | Should -Be 70
            $r.ControlCount  | Should -Be 2
            $r.ScoreDate     | Should -Not -BeNullOrEmpty
        }

        It '-IncludeControls returns per-control rows' {
            $r = Get-GkSecureScore -IncludeControls
            $r.Count | Should -Be 2
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.SecureScoreControl'
            ($r | Where-Object ControlName -eq 'BlockLegacyAuth').Score | Should -Be 0
        }

        It 'warns when no score data is returned' {
            Mock Invoke-GkRawGraphCall {
                [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{ value = @() } }
            }
            $warnings = @()
            $r = Get-GkSecureScore -WarningVariable warnings -WarningAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'Secure Score'
        }
    }
}
