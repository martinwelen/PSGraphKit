Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'New-GkGuestInvitation' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.Invite.All') } }
            Mock Invoke-GkGraphRequest { @{ inviteRedeemUrl = 'https://redeem.example/abc'; invitedUser = @{ id = 'guest-1' } } }
        }

        It 'does NOT call Graph under -WhatIf' {
            New-GkGuestInvitation -EmailAddress 'partner@fabrikam.com' -WhatIf | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'POSTs an invitation and captures the redeem URL and invited user id' {
            $r = New-GkGuestInvitation -EmailAddress 'partner@fabrikam.com' -DisplayName 'Partner' -Confirm:$false
            $r.Outcome       | Should -Be 'Invited'
            $r.RedeemUrl     | Should -Be 'https://redeem.example/abc'
            $r.InvitedUserId | Should -Be 'guest-1'
            $r.PSTypeNames[0] | Should -Be 'PSGraphKit.GuestInvitationResult'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*/invitations' -and
                $Body.invitedUserEmailAddress -eq 'partner@fabrikam.com' -and $Body.invitedUserDisplayName -eq 'Partner'
            }
        }

        It 'warns and returns Failed on error' {
            Mock Invoke-GkGraphRequest { throw 'denied' }
            $warnings = @()
            $r = New-GkGuestInvitation -EmailAddress 'partner@fabrikam.com' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            ($warnings -join ' ') | Should -Match 'partner@fabrikam.com'
        }

        It 'processes multiple addresses from the pipeline' {
            $r = 'a@fabrikam.com', 'b@fabrikam.com' | New-GkGuestInvitation -Confirm:$false
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly
        }
    }
}
