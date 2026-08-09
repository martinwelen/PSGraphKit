# New-GkTemporaryAccessPass

## SYNOPSIS
Issue a Temporary Access Pass so a user can register a strong credential.

## SYNTAX
```
New-GkTemporaryAccessPass [-UserId] <string[]> [[-LifetimeInMinutes] <int>] [[-StartDateTime] <datetime>] [-Reusable] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Calls POST /users/{id}/authentication/temporaryAccessPassMethods. A TAP is a time-boxed
passcode that satisfies MFA once, which is how you onboard someone to a passkey or recover
an account that has lost every method — without handing out a standing password.

The passcode is returned as plain text on the result but is NOT shown by the default view,
so it does not splash across the screen or into a transcript. Capture it deliberately with
Select-Object TemporaryAccessPass. It cannot be retrieved again.

A user can hold only one TAP at a time; issuing a second fails until the first is deleted or
expires. State-changing: supports -WhatIf / -Confirm and prompts by default.

Requires UserAuthMethod-TAP.ReadWrite.All (or UserAuthenticationMethod.ReadWrite.All). The
read-only and non-.All variants Graph lists are not accepted here: they cannot create, or
they cover only the signed-in user's own methods. The Temporary Access Pass authentication
method must also be enabled in the tenant's authentication methods policy — check with
Get-GkAuthMethodPolicy.

## EXAMPLES

### Example 1
```powershell
New-GkTemporaryAccessPass -UserId ada@contoso.com | Select-Object UserId, TemporaryAccessPass
```
Issue a one-hour, single-use pass and capture it.

### Example 2
```powershell
New-GkTemporaryAccessPass -UserId ada@contoso.com -LifetimeInMinutes 480 -Reusable
```
An eight-hour reusable pass, for someone setting up a new device across a working day.

### Example 3
```powershell
New-GkTemporaryAccessPass -UserId ada@contoso.com -WhatIf
```

## PARAMETERS

### -UserId
One or more user object IDs or userPrincipalNames. Accepts pipeline input, including by the
UserPrincipalName / Id property.

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -LifetimeInMinutes
How long the pass stays valid, from 10 minutes to 43200 (30 days). The tenant policy may
impose a narrower range. Defaults to 60.

```yaml
Type: Int32
Required: false
Position: 2
Default value: 60
Accept pipeline input: false
```

### -StartDateTime
When the pass becomes valid. Defaults to immediately.

```yaml
Type: DateTime
Required: false
Position: 3
Default value: None
Accept pipeline input: false
```

### -Reusable
Allow the pass to be used more than once within its lifetime. Off by default: a one-time
pass is the safer choice, and the tenant policy may forbid reusable passes entirely.

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
### PSGraphKit.TemporaryAccessPassResult
