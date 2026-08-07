Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkGroupBasedLicense' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Group.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*subscribedSkus*') {
                    return @(@{ skuId = 'sku-guid-1'; skuPartNumber = 'ENTERPRISEPACK' })
                }
                return @(
                    @{ id = 'g1'; displayName = 'Licensed Staff'; assignedLicenses = @(@{ skuId = 'sku-guid-1' })
                       licenseProcessingState = @{ state = 'ProcessingComplete' } }
                    @{ id = 'g2'; displayName = 'Rolling Out'; assignedLicenses = @(@{ skuId = 'sku-guid-1' }, @{ skuId = 'sku-guid-2' })
                       licenseProcessingState = @{ state = 'Processing' } }
                    @{ id = 'g3'; displayName = 'No Licences'; assignedLicenses = @() }
                )
            }
        }

        It 'validates the connection without the extra scope by default' {
            Get-GkGroupBasedLicense | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter {
                $FunctionName -eq 'Get-GkGroupBasedLicense' -and -not $Variant
            }
        }

        It 'validates the extra subscribedSkus scope under -ResolveSkuName' {
            Get-GkGroupBasedLicense -ResolveSkuName | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $Variant -eq 'ResolveSkuName' }
        }

        It 'drops groups that assign no licence' {
            $r = @(Get-GkGroupBasedLicense)
            $r.Count | Should -Be 2
            $r.DisplayName | Should -Not -Contain 'No Licences'
        }

        It 'reads the state out of the licenseProcessingState object' {
            $r = @(Get-GkGroupBasedLicense)
            $r[0].ProcessingState | Should -Be 'ProcessingComplete'
            $r[0].IsComplete | Should -BeTrue
            $r[1].IsComplete | Should -BeFalse
        }

        It 'returns only incomplete assignments with -NotProcessedOnly' {
            $r = @(Get-GkGroupBasedLicense -NotProcessedOnly)
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Rolling Out'
        }

        It 'reports raw skuId GUIDs when names are not resolved' {
            (Get-GkGroupBasedLicense)[0].Skus | Should -Be @('sku-guid-1')
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*subscribedSkus*' }
        }

        It 'resolves SKU names with -ResolveSkuName' {
            $r = @(Get-GkGroupBasedLicense -ResolveSkuName)
            # ENTERPRISEPACK has a friendly name in the module lookup; the unmapped GUID stays raw.
            ($r[0].Skus -join ',') | Should -Not -Be 'sku-guid-1'
            ($r[1].Skus -join ',') | Should -Match 'sku-guid-2'
        }

        It 'keeps a single-SKU list an array' {
            # Guards the module-wide single-element unroll bug fixed in 0.3.5.
            $r = @(Get-GkGroupBasedLicense)
            $r[0].Skus -is [array] | Should -BeTrue
            @($r[0].Skus).Count | Should -Be 1
        }

        It 'flattens the SKU list under -AsReport' {
            (Get-GkGroupBasedLicense -AsReport)[1].Skus | Should -BeOfType [string]
        }

        It 'still reports when subscribedSkus cannot be read' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*subscribedSkus*') { throw 'denied' }
                @(@{ id = 'g1'; displayName = 'Licensed Staff'; assignedLicenses = @(@{ skuId = 'sku-guid-1' })
                     licenseProcessingState = @{ state = 'ProcessingComplete' } })
            }
            $warnings = @()
            $r = @(Get-GkGroupBasedLicense -ResolveSkuName -WarningVariable warnings -WarningAction SilentlyContinue)
            $r.Count | Should -Be 1
            $r[0].Skus | Should -Be @('sku-guid-1')
            ($warnings -join ' ') | Should -Match 'subscribedSkus'
        }
    }
}
