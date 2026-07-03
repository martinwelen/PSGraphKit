Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkAuthStrengthPolicy' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Policy.Read.AuthenticationMethod') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'b1'; displayName = 'Multifactor authentication'; policyType = 'builtIn'; allowedCombinations = @('password,sms', 'fido2') }
                    @{ id = 'b2'; displayName = 'Phishing-resistant MFA'; policyType = 'builtIn'; allowedCombinations = @('fido2', 'x509CertificateMultiFactor', 'windowsHelloForBusiness') }
                    @{ id = 'c1'; displayName = 'Our Admin Strength'; policyType = 'custom'; allowedCombinations = @('fido2') }
                )
            }
        }

        It 'emits typed rows with combination counts' {
            $r = Get-GkAuthStrengthPolicy
            $r.Count | Should -Be 3
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.AuthStrengthPolicy'
            ($r | Where-Object Id -eq 'b2').CombinationCount | Should -Be 3
        }

        It '-CustomOnly returns only custom policies' {
            $r = Get-GkAuthStrengthPolicy -CustomOnly
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Our Admin Strength'
        }
    }
}
