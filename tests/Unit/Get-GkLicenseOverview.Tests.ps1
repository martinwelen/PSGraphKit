Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkLicenseOverview' {

        BeforeAll {
            $skusPath = Join-Path $PSScriptRoot '..' 'fixtures' 'subscribedSkus.json'
            $script:SkuValue = (Get-Content $skusPath -Raw | ConvertFrom-Json -AsHashtable)['value']
        }

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Organization.Read.All', 'User.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*subscribedSkus*') { $script:SkuValue } else { @() }
            }
        }

        It 'emits one typed row per SKU' {
            $r = Get-GkLicenseOverview
            $r.Count | Should -Be 2
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.LicenseOverview'
        }

        It 'computes available seats as enabled minus assigned' {
            $e3 = Get-GkLicenseOverview | Where-Object SkuPartNumber -eq 'ENTERPRISEPACK'
            $e3.Enabled   | Should -Be 100
            $e3.Assigned  | Should -Be 92
            $e3.Available | Should -Be 8
        }

        It 'resolves a friendly name and preserves the raw part number' {
            $p2 = Get-GkLicenseOverview | Where-Object SkuPartNumber -eq 'AAD_PREMIUM_P2'
            $p2.FriendlyName | Should -Be 'Microsoft Entra ID P2'
            $p2.Warning      | Should -Be 5
        }

        It 'falls back to the part number for an unknown SKU' {
            Mock Invoke-GkGraphRequest {
                @( @{ skuId = 'x'; skuPartNumber = 'SOME_NEW_SKU'; consumedUnits = 1; prepaidUnits = @{ enabled = 2 }; servicePlans = @() } )
            }
            (Get-GkLicenseOverview)[0].FriendlyName | Should -Be 'SOME_NEW_SKU'
        }

        It 'does not query users unless -IncludeDisabledLicensed' {
            Get-GkLicenseOverview | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*/users*' }
        }

        It 'counts disabled-but-licensed users per SKU server-side with -IncludeDisabledLicensed' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*subscribedSkus*') { return $script:SkuValue }
                if ($Uri -like '*/users*') { return @{ '@odata.count' = 2; value = @() } }   # $count=true body
                @()
            }
            $e3 = Get-GkLicenseOverview -IncludeDisabledLicensed | Where-Object SkuPartNumber -eq 'ENTERPRISEPACK'
            $e3.DisabledLicensedCount | Should -Be 2
            # one $count=true users query per SKU, filtered to accountEnabled eq false, advanced-query headers
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly -ParameterFilter {
                $Uri -like '*/users*' -and $Uri -like '*accountEnabled eq false*' -and $Uri -like '*$count=true*' -and $Headers.ConsistencyLevel -eq 'eventual'
            }
        }

        It 'adds a timestamp with -AsReport' {
            (Get-GkLicenseOverview -AsReport)[0].ReportGeneratedUtc | Should -BeOfType ([datetime])
        }
    }
}
