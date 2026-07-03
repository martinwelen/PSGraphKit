Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkTenantInfo' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Organization.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(@{
                        id = 'tenant-1'; displayName = 'Contoso'; tenantType = 'AAD'; onPremisesSyncEnabled = $true
                        createdDateTime = '2019-01-01T00:00:00Z'
                        directorySizeQuota = @{ used = 1500; total = 300000 }
                        verifiedDomains = @(@{ name = 'contoso.com'; isDefault = $true }, @{ name = 'contoso.onmicrosoft.com'; isDefault = $false })
                        technicalNotificationMails = @('admin@contoso.com')
                    })
            }
        }

        It 'returns a single typed object with the default domain and quota' {
            $r = Get-GkTenantInfo
            $r.PSTypeNames[0]        | Should -Be 'PSGraphKit.TenantInfo'
            $r.DisplayName          | Should -Be 'Contoso'
            $r.DefaultDomain        | Should -Be 'contoso.com'
            $r.VerifiedDomainCount  | Should -Be 2
            $r.DirectoryUsersUsed   | Should -Be 1500
            $r.OnPremisesSyncEnabled | Should -BeTrue
        }
    }
}
