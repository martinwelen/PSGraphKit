function New-GkGuestInvitation {
    <#
    .SYNOPSIS
        Invite one or more external users as B2B guests.

    .DESCRIPTION
        Creates a guest invitation (POST /invitations). Returns the redeem URL and the created guest
        user's id per invitation.

        State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts email addresses
        from the pipeline and yields a PSGraphKit.GuestInvitationResult per invite; failures warn and
        continue. Requires the User.Invite.All scope (Guest Inviter role).

    .PARAMETER EmailAddress
        One or more email addresses to invite. Accepts pipeline input.

    .PARAMETER RedirectUrl
        Where the invited user lands after redeeming (default https://myapps.microsoft.com).

    .PARAMETER DisplayName
        Display name for the invited guest.

    .PARAMETER SendInvitationMessage
        Send the invitation email (otherwise the redeem URL is returned for you to send).

    .EXAMPLE
        New-GkGuestInvitation -EmailAddress partner@fabrikam.com -SendInvitationMessage

        Invite one guest and email them (prompts for confirmation).

    .EXAMPLE
        'a@fabrikam.com','b@fabrikam.com' | New-GkGuestInvitation -Confirm:$false | Select-Object EmailAddress, RedeemUrl

        Invite several and capture their redeem URLs.

    .EXAMPLE
        New-GkGuestInvitation -EmailAddress partner@fabrikam.com -WhatIf

        Preview the invitation without creating it.

    .OUTPUTS
        PSGraphKit.GuestInvitationResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.GuestInvitationResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Mail', 'InvitedUserEmailAddress')]
        [string[]] $EmailAddress,

        [string] $RedirectUrl = 'https://myapps.microsoft.com',

        [string] $DisplayName,

        [switch] $SendInvitationMessage
    )

    begin {
        Test-GkConnection -FunctionName 'New-GkGuestInvitation' | Out-Null
    }

    process {
        foreach ($email in $EmailAddress) {
            if ([string]::IsNullOrWhiteSpace($email)) { continue }
            if (-not $PSCmdlet.ShouldProcess($email, 'Invite as B2B guest')) { continue }

            $body = @{
                invitedUserEmailAddress = $email
                inviteRedirectUrl       = $RedirectUrl
                sendInvitationMessage   = [bool]$SendInvitationMessage
            }
            if ($DisplayName) { $body['invitedUserDisplayName'] = $DisplayName }

            $outcome = 'Invited'
            $errMsg = $null
            $redeemUrl = $null
            $invitedId = $null
            try {
                $resp = Invoke-GkGraphRequest -Raw -Method POST -Uri '/invitations' -Body $body -CallerFunction 'New-GkGuestInvitation'
                $redeemUrl = [string](Get-GkDictValue $resp 'inviteRedeemUrl')
                $invitedId = [string](Get-GkDictValue (Get-GkDictValue $resp 'invitedUser') 'id')
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to invite '$email': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName    = 'PSGraphKit.GuestInvitationResult'
                EmailAddress  = $email
                InvitedUserId = $invitedId
                RedeemUrl     = $redeemUrl
                Outcome       = $outcome
                Error         = $errMsg
            }
        }
    }
}
