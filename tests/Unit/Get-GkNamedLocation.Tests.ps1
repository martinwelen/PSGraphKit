Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkNamedLocation' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Policy.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ '@odata.type' = '#microsoft.graph.ipNamedLocation'; id = 'ip1'; displayName = 'HQ'; isTrusted = $true; ipRanges = @(@{ cidrAddress = '203.0.113.0/24' }, @{ cidrAddress = '198.51.100.0/24' }) }
                    @{ '@odata.type' = '#microsoft.graph.countryNamedLocation'; id = 'c1'; displayName = 'Allowed Countries'; countriesAndRegions = @('SE', 'NO') }
                )
            }
        }

        It 'classifies IP and country locations and flattens ranges' {
            $r = Get-GkNamedLocation
            $ip = $r | Where-Object Id -eq 'ip1'
            $ip.Type      | Should -Be 'IP'
            $ip.IsTrusted | Should -BeTrue
            $ip.IpRanges  | Should -Contain '203.0.113.0/24'
            $c = $r | Where-Object Id -eq 'c1'
            $c.Type       | Should -Be 'Country'
            $c.Countries  | Should -Contain 'SE'
        }

        It '-TrustedOnly returns only trusted IP locations' {
            $r = Get-GkNamedLocation -TrustedOnly
            $r.Count | Should -Be 1
            $r[0].Id | Should -Be 'ip1'
        }

        It '-AsReport flattens ranges to a string' {
            $ip = Get-GkNamedLocation -AsReport | Where-Object Id -eq 'ip1'
            $ip.IpRanges | Should -BeOfType ([string])
        }
    }
}
