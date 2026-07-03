# New-GkGuestInvitation

## SYNOPSIS
Invite one or more external users as B2B guests.

## SYNTAX
```
New-GkGuestInvitation [-EmailAddress] <string[]> [[-RedirectUrl] <string>] [[-DisplayName] <string>] [-SendInvitationMessage] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Creates a guest invitation (POST /invitations). Returns the redeem URL and the created guest
user's id per invitation.

State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts email addresses
from the pipeline and yields a PSGraphKit.GuestInvitationResult per invite; failures warn and
continue. Requires the User.Invite.All scope (Guest Inviter role).

## EXAMPLES

### Example 1
```powershell
New-GkGuestInvitation -EmailAddress partner@fabrikam.com -SendInvitationMessage
```
Invite one guest and email them (prompts for confirmation).

### Example 2
```powershell
'a@fabrikam.com','b@fabrikam.com' | New-GkGuestInvitation -Confirm:$false | Select-Object EmailAddress, RedeemUrl
```
Invite several and capture their redeem URLs.

### Example 3
```powershell
New-GkGuestInvitation -EmailAddress partner@fabrikam.com -WhatIf
```
Preview the invitation without creating it.

## PARAMETERS

### -EmailAddress
One or more email addresses to invite. Accepts pipeline input.

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -RedirectUrl
Where the invited user lands after redeeming (default https://myapps.microsoft.com).

```yaml
Type: String
Required: false
Position: 2
Default value: https://myapps.microsoft.com
Accept pipeline input: false
```

### -DisplayName
Display name for the invited guest.

```yaml
Type: String
Required: false
Position: 3
Default value: None
Accept pipeline input: false
```

### -SendInvitationMessage
Send the invitation email (otherwise the redeem URL is returned for you to send).

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### CommonParameters
This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, -WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. For more information, see about_CommonParameters.

## INPUTS
### None

## OUTPUTS
### PSGraphKit.GuestInvitationResult
