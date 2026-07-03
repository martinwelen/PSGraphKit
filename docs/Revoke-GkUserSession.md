# Revoke-GkUserSession

## SYNOPSIS
Revoke the active sign-in sessions (refresh tokens) of one or more users, forcing
re-authentication.

## SYNTAX
```
Revoke-GkUserSession [-UserId] <string[]> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Calls POST /users/{id}/revokeSignInSessions, which resets the user's
signInSessionsValidFromDateTime so existing tokens can no longer be refreshed. Useful for
offboarding, suspected compromise, or after a password reset.

This is a state-changing operation: it supports -WhatIf / -Confirm and prompts by default.
Accepts users from the pipeline, so it composes with the reporting cmdlets. Each processed
user yields a PSGraphKit.SessionRevokeResult; a failure warns and continues rather than
aborting a bulk run.

Notes: external/B2B guests are not affected (they authenticate in their home tenant), and
revocation takes a few minutes to propagate. Requires the User.RevokeSessions.All scope
(plus a supporting Entra role, e.g. User Administrator, to act on other users).

## EXAMPLES

### Example 1
```powershell
Revoke-GkUserSession -UserId ada@contoso.com
```
Revoke one user's sessions (prompts for confirmation).

### Example 2
```powershell
Get-GkStaleUser -InactiveDays 180 | Revoke-GkUserSession -WhatIf
```
Preview revoking sessions for every user stale 180+ days, without making changes.

### Example 3
```powershell
'ada@contoso.com','bob@contoso.com' | Revoke-GkUserSession -Confirm:$false |
    Where-Object Outcome -eq 'Failed'
```
Revoke without prompting and inspect any failures.

## PARAMETERS

### -UserId
One or more user object IDs or userPrincipalNames. Accepts pipeline input, including by the
UserPrincipalName / Id property so report output can be piped in.

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### CommonParameters
This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, -WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. For more information, see about_CommonParameters.

## INPUTS
### None

## OUTPUTS
### PSGraphKit.SessionRevokeResult
