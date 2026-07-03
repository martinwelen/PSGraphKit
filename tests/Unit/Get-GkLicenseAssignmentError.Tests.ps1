Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkLicenseAssignmentError' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.Read.All', 'Organization.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*subscribedSkus*') {
                    return @(@{ skuId = 'sku-e3'; skuPartNumber = 'ENTERPRISEPACK' })
                }
                @(
                    @{ id = 'u1'; userPrincipalName = 'ada@contoso.com'; licenseAssignmentStates = @(
                            @{ skuId = 'sku-e3'; state = 'Error'; error = 'CountViolation'; assignedByGroup = $null }
                            @{ skuId = 'sku-e3'; state = 'Active'; error = $null; assignedByGroup = $null }
                        ) }
                    @{ id = 'u2'; userPrincipalName = 'bob@contoso.com'; licenseAssignmentStates = @(
                            @{ skuId = 'sku-e3'; state = 'ActiveWithError'; error = 'DependencyViolation'; assignedByGroup = 'grp-1' }
                        ) }
                    @{ id = 'u3'; userPrincipalName = 'clean@contoso.com'; licenseAssignmentStates = @() }
                )
            }
        }

        It 'emits one row per erroring SKU only' {
            $r = Get-GkLicenseAssignmentError
            $r.Count | Should -Be 2   # ada (Error) + bob (ActiveWithError); the Active state and clean user excluded
        }

        It 'resolves the SKU part number and flags group-based failures' {
            $ada = Get-GkLicenseAssignmentError | Where-Object UserPrincipalName -eq 'ada@contoso.com'
            $ada.SkuPartNumber   | Should -Be 'ENTERPRISEPACK'
            $ada.FriendlyName    | Should -Be 'Office 365 E3'
            $ada.AssignedByGroup | Should -BeFalse
            $bob = Get-GkLicenseAssignmentError | Where-Object UserPrincipalName -eq 'bob@contoso.com'
            $bob.AssignedByGroup | Should -BeTrue
            $bob.ErrorCode       | Should -Be 'DependencyViolation'
        }
    }
}
