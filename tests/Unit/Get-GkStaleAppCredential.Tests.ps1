Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkStaleAppCredential' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('AuditLog.Read.All', 'Application.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*appCredentialSignInActivities*') {
                    return @(
                        @{ appId = 'app-1'; keyId = 'k1'; keyType = 'Password'; credentialOrigin = 'application'; signInActivity = @{ lastSignInDateTime = '2023-01-01T00:00:00Z' } }
                        @{ appId = 'app-2'; keyId = 'k2'; keyType = 'Certificate'; credentialOrigin = 'application' }
                    )
                }
                if ($Uri -like '*servicePrincipals?*') { return @(@{ appId = 'app-1'; displayName = 'App One' }) }
                @()
            }
        }

        It 'uses the beta endpoint and flags never-used credentials' {
            $r = Get-GkStaleAppCredential
            Should -Invoke Invoke-GkGraphRequest -ParameterFilter { $Uri -like '*appCredentialSignInActivities*' -and $ApiVersion -eq 'beta' }
            ($r | Where-Object KeyId -eq 'k2').NeverUsed | Should -BeTrue
            ($r | Where-Object KeyId -eq 'k1').AppDisplayName | Should -Be 'App One'
        }

        It 'warns when the beta report is unavailable' {
            Mock Invoke-GkGraphRequest { if ($Uri -like '*appCredentialSignInActivities*') { throw 'not available' } }
            $warnings = @()
            Get-GkStaleAppCredential -WarningVariable warnings -WarningAction SilentlyContinue | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'beta'
        }
    }
}
