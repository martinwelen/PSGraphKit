Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkSubscription' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Organization.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 's1'; skuPartNumber = 'ENTERPRISEPACK'; status = 'Enabled'; totalLicenses = 100; isTrial = $false; nextLifecycleDateTime = ([datetime]::UtcNow.AddDays(30).ToString('o')); createdDateTime = '2024-01-01T00:00:00Z' }
                    @{ id = 's2'; skuPartNumber = 'AAD_PREMIUM_P2'; status = 'Enabled'; totalLicenses = 50; isTrial = $true; nextLifecycleDateTime = ([datetime]::UtcNow.AddDays(200).ToString('o')); createdDateTime = '2025-01-01T00:00:00Z' }
                )
            }
        }

        It 'resolves the friendly name and computes days until renewal' {
            $r = Get-GkSubscription
            $e3 = $r | Where-Object SkuPartNumber -eq 'ENTERPRISEPACK'
            $e3.FriendlyName     | Should -Be 'Office 365 E3'
            $e3.DaysUntilRenewal | Should -BeGreaterThan 25
            $e3.DaysUntilRenewal | Should -BeLessThan 35
        }

        It '-ExpiringInDays filters to soon-to-lapse subscriptions' {
            $r = Get-GkSubscription -ExpiringInDays 60
            $r.Count | Should -Be 1
            $r[0].SkuPartNumber | Should -Be 'ENTERPRISEPACK'
        }
    }
}
