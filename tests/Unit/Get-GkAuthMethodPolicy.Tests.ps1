Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkAuthMethodPolicy' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Policy.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @{ id = 'authpolicy'; authenticationMethodConfigurations = @(
                        @{ id = 'Fido2'; state = 'enabled' }
                        @{ id = 'Sms'; state = 'disabled' }
                        @{ id = 'MicrosoftAuthenticator'; state = 'enabled' }
                    ) }
            }
        }

        It 'emits one typed row per method' {
            $r = Get-GkAuthMethodPolicy
            $r.Count | Should -Be 3
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.AuthMethodState'
            ($r | Where-Object Method -eq 'Fido2').State | Should -Be 'enabled'
        }

        It '-EnabledOnly returns only enabled methods' {
            $r = Get-GkAuthMethodPolicy -EnabledOnly
            $r.Count | Should -Be 2
            $r.State | Should -Not -Contain 'disabled'
        }
    }
}
