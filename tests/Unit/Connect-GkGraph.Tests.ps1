Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Connect-GkGraph' {

        BeforeEach {
            Mock Connect-MgGraph { }
            Mock Get-MgContext { [pscustomobject]@{ Account = 'admin@contoso.com'; AuthType = 'Delegated'; TenantId = 't1'; ClientId = 'c1'; AppName = 'app'; Scopes = @('User.Read.All') } }
            Mock Get-GkCurrentUserRole { @('Global Reader') }
        }

        It 'derives scopes for -ForCommand and connects delegated' {
            Connect-GkGraph -ForCommand Get-GkStaleUser | Out-Null
            Should -Invoke Connect-MgGraph -Times 1 -Exactly -ParameterFilter {
                ($Scopes -contains 'User.Read.All') -and ($Scopes -contains 'AuditLog.Read.All')
            }
        }

        It 'unions scopes across multiple commands plus explicit -Scopes' {
            Connect-GkGraph -ForCommand Get-GkDeviceInventory -Scopes 'Custom.Scope' | Out-Null
            Should -Invoke Connect-MgGraph -Times 1 -Exactly -ParameterFilter {
                ($Scopes -contains 'Device.Read.All') -and ($Scopes -contains 'Custom.Scope')
            }
        }

        It '-AllCommands requests a broad set including several distinct scopes' {
            Connect-GkGraph -AllCommands | Out-Null
            Should -Invoke Connect-MgGraph -Times 1 -Exactly -ParameterFilter {
                ($Scopes -contains 'Policy.Read.All') -and ($Scopes -contains 'Device.Read.All') -and ($Scopes -contains 'AuditLog.Read.All')
            }
        }

        It 'returns the connection info after connecting' {
            $r = Connect-GkGraph -Scopes 'User.Read.All'
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.ConnectionInfo'
            $r.IsConnected    | Should -BeTrue
        }

        It 'uses app-only parameters and ignores scopes when -ClientId is given' {
            Connect-GkGraph -ClientId 'app-1' -TenantId 'contoso.onmicrosoft.com' -CertificateThumbprint 'ABCD' -ForCommand Get-GkStaleUser | Out-Null
            Should -Invoke Connect-MgGraph -Times 1 -Exactly -ParameterFilter {
                $ClientId -eq 'app-1' -and $TenantId -eq 'contoso.onmicrosoft.com' -and $CertificateThumbprint -eq 'ABCD' -and (-not $Scopes)
            }
        }

        It 'throws when app-only is missing a certificate' {
            { Connect-GkGraph -ClientId 'app-1' -TenantId 'contoso.onmicrosoft.com' } |
                Should -Throw -ExpectedMessage '*certificate*'
        }

        It 'throws when app-only is missing the tenant' {
            { Connect-GkGraph -ClientId 'app-1' -CertificateThumbprint 'ABCD' } |
                Should -Throw -ExpectedMessage '*TenantId*'
        }

        It 'throws for a delegated connect with no scopes requested' {
            { Connect-GkGraph } | Should -Throw -ExpectedMessage '*-Scopes*'
        }

        It 'warns for an unknown cmdlet name in -ForCommand' {
            $warnings = @()
            Connect-GkGraph -ForCommand 'Get-GkStaleUser', 'Get-GkNotReal' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
            ($warnings -join ' ') | Should -Match 'Get-GkNotReal'
        }
    }
}
