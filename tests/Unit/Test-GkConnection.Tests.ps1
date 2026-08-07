Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Test-GkConnection' {

        It 'throws an actionable error when not connected' {
            Mock Get-MgContext { $null }
            { Test-GkConnection -FunctionName 'Get-GkStaleUser' } |
                Should -Throw -ExpectedMessage '*Connect-GkGraph -ForCommand Get-GkStaleUser*'
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

    Describe 'Test-GkConnection — accountEnabled scope combination' {

        It 'rejects User.EnableDisableAccount.All alone: it carries no read of the target user' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.EnableDisableAccount.All') } }
            { Test-GkConnection -FunctionName 'Disable-GkStaleUser' } |
                Should -Throw -ExpectedMessage '*read the target user*'
        }

        It 'accepts the documented least-privileged combination' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.EnableDisableAccount.All', 'User.Read.All') } }
            { Test-GkConnection -FunctionName 'Disable-GkStaleUser' } | Should -Not -Throw
        }

        It 'accepts User.ReadUpdate.All alone (least privileged for PATCH /users since July 2026)' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.ReadUpdate.All') } }
            { Test-GkConnection -FunctionName 'Disable-GkStaleUser' } | Should -Not -Throw
        }

        It 'still accepts the broad write scopes on their own' {
            foreach ($scope in 'User.ReadWrite.All', 'Directory.ReadWrite.All') {
                Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @($scope) } }.GetNewClosure()
                { Test-GkConnection -FunctionName 'Disable-GkStaleUser' } | Should -Not -Throw
            }
        }
    }

    Describe 'Test-GkConnection — action-specific scope variants' {

        It 'accepts User.ReadUpdate.All for the disable path' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.ReadUpdate.All') } }
            { Test-GkConnection -FunctionName 'Remove-GkStaleGuest' } | Should -Not -Throw
        }

        It 'rejects User.ReadUpdate.All for the delete path: DELETE /users needs User.ReadWrite.All' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.ReadUpdate.All') } }
            { Test-GkConnection -FunctionName 'Remove-GkStaleGuest' -Variant 'Delete' } |
                Should -Throw -ExpectedMessage '*soft-delete*'
        }

        It 'accepts User.ReadWrite.All for the delete path' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.ReadWrite.All') } }
            { Test-GkConnection -FunctionName 'Remove-GkStaleGuest' -Variant 'Delete' } | Should -Not -Throw
        }

        It 'falls back to the plain entry for an unmapped variant' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.ReadUpdate.All') } }
            { Test-GkConnection -FunctionName 'Remove-GkStaleGuest' -Variant 'NoSuchVariant' } | Should -Not -Throw
        }
    }

    Describe 'Connection failures point at Connect-GkGraph' {

        It 'leads the not-connected hint with Connect-GkGraph -ForCommand' {
            Mock Get-MgContext { $null }
            { Test-GkConnection -FunctionName 'Get-GkStaleUser' } |
                Should -Throw -ExpectedMessage '*Run: Connect-GkGraph -ForCommand Get-GkStaleUser*'
        }

        It 'leads the missing-scope hint with Connect-GkGraph -ForCommand' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.Read') } }
            { Test-GkConnection -FunctionName 'Get-GkStaleUser' } |
                Should -Throw -ExpectedMessage '*Connect-GkGraph -ForCommand Get-GkStaleUser*'
        }

        It 'leads the app-only hint with Connect-GkGraph -ForCommand' {
            Mock Get-MgContext { [pscustomobject]@{ AuthType = 'AppOnly'; Scopes = @('Directory.Read.All') } }
            { Test-GkConnection -FunctionName 'Get-GkUserAccessReport' } |
                Should -Throw -ExpectedMessage '*Connect-GkGraph -ForCommand Get-GkUserAccessReport*'
        }

        It 'still names the raw scopes so a manual Connect-MgGraph stays possible' {
            Mock Get-MgContext { $null }
            { Test-GkConnection -FunctionName 'Get-GkStaleUser' } |
                Should -Throw -ExpectedMessage '*Connect-MgGraph -Scopes User.Read.All,AuditLog.Read.All*'
        }
    }

    Describe 'Get-GkConnectCommandHint' {
        It 'names the cmdlet and keeps the raw scopes as a secondary note' {
            $hint = Get-GkConnectCommandHint -FunctionName 'Get-GkStaleUser'
            $hint | Should -BeLike 'Connect-GkGraph -ForCommand Get-GkStaleUser*'
            $hint | Should -BeLike '*Connect-MgGraph -Scopes User.Read.All,AuditLog.Read.All*'
        }

        It 'reflects the action variant in the raw scopes' {
            Get-GkConnectCommandHint -FunctionName 'Remove-GkStaleGuest' -Variant 'Delete' |
                Should -BeLike '*Connect-MgGraph -Scopes User.ReadWrite.All*'
        }
    }

    Describe 'Error attribution' {

        It 'attributes the failure to the public cmdlet the user typed' {
            Mock Get-MgContext { $null }
            $err = $null
            try { Get-GkStaleUser -ErrorAction Stop } catch { $err = $_ }
            $err | Should -Not -BeNullOrEmpty
            $err.InvocationInfo.MyCommand.Name | Should -Be 'Get-GkStaleUser'
            $err.CategoryInfo.Activity | Should -Be 'Get-GkStaleUser'
            $err.FullyQualifiedErrorId | Should -BeLike 'GkNotConnected*'
        }

        It 'falls back to the helper when no caller is supplied' {
            Mock Get-MgContext { $null }
            $err = $null
            try { Test-GkConnection -FunctionName 'Get-GkStaleUser' } catch { $err = $_ }
            $err.InvocationInfo.MyCommand.Name | Should -Be 'Test-GkConnection'
        }
    }

    Describe 'Resolve-GkScopeMapKey' {
        It 'prefers the variant key when one is mapped' {
            Resolve-GkScopeMapKey -FunctionName 'Remove-GkStaleGuest' -Variant 'Delete' |
                Should -Be 'Remove-GkStaleGuest:Delete'
        }
        It 'falls back to the plain key' {
            Resolve-GkScopeMapKey -FunctionName 'Remove-GkStaleGuest' -Variant 'Nope' |
                Should -Be 'Remove-GkStaleGuest'
        }
        It 'returns null for an unmapped function' {
            Resolve-GkScopeMapKey -FunctionName 'Get-GkNotAThing' | Should -BeNullOrEmpty
        }
    }

    Describe 'Get-GkConnectScopeHint' {
        It 'produces one least-privileged scope per capability group' {
            $hint = Get-GkConnectScopeHint -FunctionName 'Get-GkStaleUser'
            $hint | Should -Be 'User.Read.All,AuditLog.Read.All'
        }

        It 'hints the documented least-privileged combination for accountEnabled' {
            Get-GkConnectScopeHint -FunctionName 'Disable-GkStaleUser' |
                Should -Be 'User.EnableDisableAccount.All,User.Read.All'
        }

        It 'hints the delete-capable scope when the Delete variant is selected' {
            Get-GkConnectScopeHint -FunctionName 'Remove-GkStaleGuest' -Variant 'Delete' |
                Should -Be 'User.ReadWrite.All'
        }
    }
}
