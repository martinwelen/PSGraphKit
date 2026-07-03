Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkCustomRole' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('RoleManagement.Read.Directory') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'cr1'; displayName = 'Helpdesk Lite'; isEnabled = $true; description = 'reset passwords'
                       rolePermissions = @(@{ allowedResourceActions = @('microsoft.directory/users/password/update', 'microsoft.directory/users/basic/read') }) }
                    @{ id = 'cr2'; displayName = 'Disabled Role'; isEnabled = $false; description = ''; rolePermissions = @(@{ allowedResourceActions = @('microsoft.directory/groups/basic/read') }) }
                )
            }
        }

        It 'filters to custom roles and counts permissions' {
            $r = Get-GkCustomRole
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -ParameterFilter { $Uri -like '*isBuiltIn eq false*' }
            ($r | Where-Object Id -eq 'cr1').PermissionCount | Should -Be 2
        }

        It 'exposes IsEnabled and the permission list' {
            $r = Get-GkCustomRole
            ($r | Where-Object Id -eq 'cr2').IsEnabled | Should -BeFalse
            ($r | Where-Object Id -eq 'cr1').Permissions | Should -Contain 'microsoft.directory/users/password/update'
        }

        It '-AsReport flattens permissions to a string' {
            (Get-GkCustomRole -AsReport)[0].Permissions | Should -BeOfType ([string])
        }
    }
}
