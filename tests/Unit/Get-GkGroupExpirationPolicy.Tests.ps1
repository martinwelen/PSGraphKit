Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkGroupExpirationPolicy' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Directory.Read.All') } }
        }

        It 'emits the configured policy and splits notification emails' {
            Mock Invoke-GkGraphRequest {
                @(@{ id = 'p1'; groupLifetimeInDays = 180; managedGroupTypes = 'Selected'; alternateNotificationEmails = 'a@contoso.com;b@contoso.com' })
            }
            $r = Get-GkGroupExpirationPolicy
            $r.PSTypeNames[0]           | Should -Be 'PSGraphKit.GroupExpirationPolicy'
            $r.GroupLifetimeInDays      | Should -Be 180
            $r.AlternateNotificationEmails | Should -Contain 'b@contoso.com'
        }

        It 'returns nothing when no policy is configured' {
            Mock Invoke-GkGraphRequest { @() }
            Get-GkGroupExpirationPolicy | Should -BeNullOrEmpty
        }
    }
}
