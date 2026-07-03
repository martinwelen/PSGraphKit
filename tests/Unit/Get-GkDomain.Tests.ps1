Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkDomain' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Domain.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'contoso.com'; isVerified = $true; isDefault = $true; authenticationType = 'Managed'; isAdminManaged = $true; supportedServices = @('Email', 'OfficeCommunicationsOnline') }
                    @{ id = 'fed.contoso.com'; isVerified = $true; isDefault = $false; authenticationType = 'Federated'; isAdminManaged = $true; supportedServices = @('Email') }
                )
            }
        }

        It 'emits typed rows' {
            $r = Get-GkDomain
            $r.Count | Should -Be 2
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.Domain'
            ($r | Where-Object Name -eq 'contoso.com').IsDefault | Should -BeTrue
        }

        It '-FederatedOnly returns only federated domains' {
            $r = Get-GkDomain -FederatedOnly
            $r.Count | Should -Be 1
            $r[0].Name | Should -Be 'fed.contoso.com'
        }
    }
}
