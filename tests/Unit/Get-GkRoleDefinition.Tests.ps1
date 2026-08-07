Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkRoleDefinition' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('RoleManagement.Read.Directory') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'r1'; displayName = 'Global Administrator'; description = 'Full access'; isBuiltIn = $true; isEnabled = $true
                       templateId = 't1'; rolePermissions = @(@{ allowedResourceActions = @('microsoft.directory/users/create', 'microsoft.directory/users/delete') }) }
                    @{ id = 'r2'; displayName = 'Helpdesk Reader'; description = 'Custom'; isBuiltIn = $false; isEnabled = $true
                       templateId = 't2'; rolePermissions = @(@{ allowedResourceActions = @('microsoft.directory/users/standard/read') }) }
                )
            }
        }

        It 'validates the connection' {
            Get-GkRoleDefinition | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Get-GkRoleDefinition' }
        }

        It 'counts the allowed resource actions' {
            $r = @(Get-GkRoleDefinition)
            $r[0].PermissionCount | Should -Be 2
            $r[1].PermissionCount | Should -Be 1
        }

        It 'omits the permission list unless asked' {
            (Get-GkRoleDefinition)[0].PSObject.Properties.Name | Should -Not -Contain 'Permissions'
        }

        It 'includes the permission list with -IncludePermission' {
            $r = @(Get-GkRoleDefinition -IncludePermission)
            @($r[0].Permissions).Count | Should -Be 2
        }

        It 'flattens the permission list under -AsReport' {
            $r = @(Get-GkRoleDefinition -IncludePermission -AsReport)
            $r[0].Permissions | Should -BeOfType [string]
            $r[0].Permissions | Should -Match 'users/create'
        }

        It 'filters server-side for -Scope BuiltIn' {
            Get-GkRoleDefinition -Scope BuiltIn | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*isBuiltIn eq true*' }
        }

        It 'filters server-side for -Scope Custom' {
            Get-GkRoleDefinition -Scope Custom | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*isBuiltIn eq false*' }
        }

        It 'matches -Name case-insensitively and as a substring' {
            $r = @(Get-GkRoleDefinition -Name 'helpdesk')
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Helpdesk Reader'
        }

        It 'keeps a single-action permission list an array' {
            # Guards the module-wide single-element unroll bug fixed in 0.3.5.
            $r = @(Get-GkRoleDefinition -Name 'Helpdesk' -IncludePermission)
            $r[0].Permissions -is [array] | Should -BeTrue
            @($r[0].Permissions).Count | Should -Be 1
        }
    }
}
