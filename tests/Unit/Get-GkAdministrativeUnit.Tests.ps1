Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkAdministrativeUnit' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('AdministrativeUnit.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*/members*') { return @{ '@odata.count' = 12 } }
                @(
                    @{ id = 'au1'; displayName = 'EMEA'; visibility = 'Public'; membershipRule = $null }
                    @{ id = 'au2'; displayName = 'Sales (Dynamic)'; visibility = $null; membershipRule = "(user.department -eq 'Sales')" }
                )
            }
        }

        It 'classifies dynamic vs assigned and fetches member counts' {
            $r = Get-GkAdministrativeUnit
            ($r | Where-Object Id -eq 'au1').MembershipType | Should -Be 'Assigned'
            ($r | Where-Object Id -eq 'au2').MembershipType | Should -Be 'Dynamic'
            $r[0].MemberCount | Should -Be 12
        }

        It '-SkipMemberCount avoids the members call' {
            $r = Get-GkAdministrativeUnit -SkipMemberCount
            $r[0].MemberCount | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*/members*' }
        }
    }
}
