Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Remove-GkUserLicense' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('LicenseAssignment.ReadWrite.All') } }
            Mock Invoke-GkGraphRequest { @{ id = 'u1' } }   # assignLicense returns the user
        }

        It 'validates the connection before acting' {
            Remove-GkUserLicense -UserId 'ada@contoso.com' -SkuId 'sku-1' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Remove-GkUserLicense' }
        }

        It 'does NOT call Graph under -WhatIf' {
            Remove-GkUserLicense -UserId 'ada@contoso.com' -SkuId 'sku-1' -WhatIf | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'POSTs assignLicense with removeLicenses and returns a Removed result' {
            $r = Remove-GkUserLicense -UserId 'ada@contoso.com' -SkuId 'sku-1', 'sku-2' -Confirm:$false
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.LicenseRemoveResult'
            $r.Outcome | Should -Be 'Removed'
            $r.SkuId   | Should -Be 'sku-1; sku-2'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*/assignLicense' -and
                ($Body.removeLicenses -contains 'sku-1') -and ($Body.removeLicenses -contains 'sku-2') -and
                ($Body.addLicenses.Count -eq 0)
            }
        }

        It 'warns and returns Failed when the call errors (e.g. group-based license)' {
            Mock Invoke-GkGraphRequest { throw 'cannot remove group-assigned license' }
            $warnings = @()
            $r = Remove-GkUserLicense -UserId 'ada@contoso.com' -SkuId 'sku-1' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            ($warnings -join ' ') | Should -Match 'ada@contoso.com'
        }

        It 'processes multiple users from the pipeline' {
            $r = 'a@contoso.com', 'b@contoso.com' | Remove-GkUserLicense -SkuId 'sku-1' -Confirm:$false
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly
        }
    }
}
