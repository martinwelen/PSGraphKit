Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkConditionalAccessTemplate' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Policy.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 't1'; name = 'Require MFA for admins'; description = 'protect admins'; scenarios = @('secureFoundation', 'protectAdmins') }
                    @{ id = 't2'; name = 'Block legacy authentication'; description = 'block legacy'; scenarios = @('secureFoundation') }
                )
            }
        }

        It 'emits typed rows with scenarios' {
            $r = Get-GkConditionalAccessTemplate
            $r.Count | Should -Be 2
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.CaTemplate'
        }

        It '-Scenario filters to matching templates' {
            $r = Get-GkConditionalAccessTemplate -Scenario protectAdmins
            $r.Count | Should -Be 1
            $r[0].Name | Should -Be 'Require MFA for admins'
        }
    }
}
