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
                    allowUserConsentForRiskyApps = $false
                    defaultUserRolePermissions = @{ allowedToCreateApps = $true; allowedToCreateSecurityGroups = $false; allowedToReadOtherUsers = $true; permissionGrantPoliciesAssigned = @('ManagePermissionGrantsForSelf.microsoft-user-default-low') }
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

        It 'reports user app-consent (from permissionGrantPoliciesAssigned) separately from the risky-apps toggle' {
            $r = Get-GkExternalCollaborationSetting
            $r.AllowUserConsentForApps      | Should -BeTrue    # a grant policy is assigned
            $r.AllowUserConsentForRiskyApps | Should -BeFalse   # the separate risky-apps toggle
        }
    }
}
