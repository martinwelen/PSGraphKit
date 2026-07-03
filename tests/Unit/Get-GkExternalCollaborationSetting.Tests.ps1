Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkExternalCollaborationSetting' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Policy.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @{
                    allowInvitesFrom = 'everyone'
                    guestUserRoleId  = '10dae51f-b6af-4016-8d66-8c2a99b929b3'
                    allowEmailVerifiedUsersToJoinOrganization = $false
                    defaultUserRolePermissions = @{ allowedToCreateApps = $true; allowedToCreateSecurityGroups = $false; allowedToReadOtherUsers = $true }
                }
            }
        }

        It 'returns a single typed object with mapped guest role and default permissions' {
            $r = Get-GkExternalCollaborationSetting
            $r.PSTypeNames[0]            | Should -Be 'PSGraphKit.ExternalCollaborationSetting'
            $r.AllowInvitesFrom         | Should -Be 'everyone'
            $r.GuestUserRole            | Should -Be 'Guest User (default)'
            $r.DefaultUserCanCreateApps | Should -BeTrue
            $r.DefaultUserCanCreateSecurityGroups | Should -BeFalse
        }
    }
}
