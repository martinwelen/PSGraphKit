Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkConnectionInfo' {

        It 'reports not-connected without throwing' {
            Mock Get-MgContext { $null }
            $r = Get-GkConnectionInfo
            $r.IsConnected | Should -BeFalse
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.ConnectionInfo'
            $r.Scopes.Count | Should -Be 0
        }

        It 'reports a delegated identity with active roles' {
            Mock Get-MgContext {
                [pscustomobject]@{ Account = 'admin@contoso.com'; AuthType = 'Delegated'; TenantId = 't1'; ClientId = 'c1'; AppName = 'app'; Scopes = @('User.Read.All', 'AuditLog.Read.All') }
            }
            Mock Get-GkCurrentUserRole { @('Global Reader') }

            $r = Get-GkConnectionInfo
            $r.IsConnected | Should -BeTrue
            $r.Account     | Should -Be 'admin@contoso.com'
            $r.AuthType    | Should -Be 'Delegated'
            $r.ActiveRoles | Should -Contain 'Global Reader'
        }

        It 'does not query roles for an app-only session' {
            Mock Get-MgContext {
                [pscustomobject]@{ Account = $null; AuthType = 'AppOnly'; TenantId = 't1'; ClientId = 'c1'; AppName = 'app'; Scopes = @('Directory.Read.All') }
            }
            Mock Get-GkCurrentUserRole { throw 'roles must not be queried for app-only' }

            $r = Get-GkConnectionInfo
            $r.ActiveRoles.Count | Should -Be 0
            Should -Invoke Get-GkCurrentUserRole -Times 0 -Exactly
        }
    }
}
