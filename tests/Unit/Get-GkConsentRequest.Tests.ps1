Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkConsentRequest' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('ConsentRequest.Read.All') } }
            # Real appConsentRequest shape: pending permissions live in the pendingScopes collection
            # (there is no pendingScopeCount/consentType property on the resource).
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'r1'; appDisplayName = 'Cool App'; appId = 'app-1'; pendingScopes = @(
                            @{ displayName = 'Read all users' }, @{ displayName = 'Read directory data' }, @{ displayName = 'Send mail' }) }
                    @{ id = 'r2'; appDisplayName = 'Other App'; appId = 'app-2'; pendingScopes = @(@{ displayName = 'Read calendars' }) }
                )
            }
        }

        It 'derives the pending scope count and names from pendingScopes' {
            $r = Get-GkConsentRequest
            $r.Count | Should -Be 2
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.ConsentRequest'
            ($r | Where-Object Id -eq 'r1').PendingScopeCount | Should -Be 3
            ($r | Where-Object Id -eq 'r1').PendingScopes     | Should -Contain 'Read all users'
            ($r | Where-Object Id -eq 'r2').PendingScopeCount | Should -Be 1
        }

        It 'warns and returns nothing when unavailable' {
            Mock Invoke-GkGraphRequest { throw 'workflow not enabled' }
            $warnings = @()
            Get-GkConsentRequest -WarningVariable warnings -WarningAction SilentlyContinue | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'consent'
        }
    }
}
