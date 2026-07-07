Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkTenantInfo' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Organization.Read.All') } }

            # Mock the low-level seam so the REAL Invoke-GkGraphRequest runs its single-object (non-unrolling)
            # return contract — the shape that made the old @(...) | Select-Object -First 1 consumer hand back
            # the whole array and null every field. A plain-array mock of Invoke-GkGraphRequest hid that.
            Mock Invoke-GkRawGraphCall {
                [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{
                    value = @(@{
                        id = 'tenant-1'; displayName = 'Contoso'; tenantType = 'AAD'; onPremisesSyncEnabled = $true
                        createdDateTime = '2019-01-01T00:00:00Z'
                        directorySizeQuota = @{ used = 1500; total = 300000 }
                        verifiedDomains = @(@{ name = 'contoso.com'; isDefault = $true }, @{ name = 'contoso.onmicrosoft.com'; isDefault = $false })
                        technicalNotificationMails = @('admin@contoso.com')
                    })
                } }
            }
        }

        It 'returns a single typed object with the default domain and quota' {
            $r = Get-GkTenantInfo
            $r.PSTypeNames[0]        | Should -Be 'PSGraphKit.TenantInfo'
            $r.DisplayName          | Should -Be 'Contoso'
            $r.TenantId             | Should -Be 'tenant-1'
            $r.DefaultDomain        | Should -Be 'contoso.com'
            $r.VerifiedDomainCount  | Should -Be 2
            $r.DirectoryUsersUsed   | Should -Be 1500
            $r.OnPremisesSyncEnabled | Should -BeTrue
        }

        It 'warns when no organization data is returned' {
            Mock Invoke-GkRawGraphCall {
                [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{ value = @() } }
            }
            $warnings = @()
            $r = Get-GkTenantInfo -WarningVariable warnings -WarningAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'organization'
        }
    }
}
