Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Test-GkConnection' {

        It 'throws an actionable error when not connected' {
            Mock Get-MgContext { $null }
            { Test-GkConnection -FunctionName 'Get-GkStaleUser' } |
                Should -Throw -ExpectedMessage '*Connect-MgGraph -Scopes*'
        }

        It 'throws naming the missing capability scope' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.Read') } }
            { Test-GkConnection -FunctionName 'Get-GkStaleUser' } |
                Should -Throw -ExpectedMessage '*AuditLog.Read.All*'
        }

        It 'accepts a broad scope that satisfies a narrower capability group' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Directory.Read.All', 'AuditLog.Read.All') } }
            { Test-GkConnection -FunctionName 'Get-GkStaleUser' } | Should -Not -Throw
        }

        It 'blocks app-only sessions on a delegated-only function' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'AppOnly'; Scopes = @('Directory.Read.All') } }
            { Test-GkConnection -FunctionName 'Get-GkUserAccessReport' } |
                Should -Throw -ExpectedMessage '*delegated*'
        }

        It 'returns the context on success' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Group.Read.All') } }
            $ctx = Test-GkConnection -FunctionName 'Get-GkGroupReport'
            $ctx.AuthType | Should -Be 'Delegated'
        }
    }

    Describe 'Get-GkConnectScopeHint' {
        It 'produces one least-privileged scope per capability group' {
            $hint = Get-GkConnectScopeHint -FunctionName 'Get-GkStaleUser'
            $hint | Should -Be 'User.Read.All,AuditLog.Read.All'
        }
    }
}
