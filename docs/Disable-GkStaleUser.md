# Disable-GkStaleUser

## SYNOPSIS
Block sign-in for one or more users by setting accountEnabled = false.

## SYNTAX
```
Disable-GkStaleUser [-UserId] <string[]> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Calls PATCH /users/{id} with { "accountEnabled": false }, blocking the account from signing
in. Typically fed from Get-GkStaleUser to remediate stale accounts, but it acts on whatever
users are supplied.

State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts users from the
pipeline and yields a PSGraphKit.UserDisableResult per user; a failure warns and continues.
Disabling is reversible (set accountEnabled back to true). Blocking a privileged/admin
account requires a higher Entra role than blocking a regular user.

Requires a scope that can update accountEnabled (User.EnableDisableAccount.All,
User.ReadUpdate.All, User.ReadWrite.All or Directory.ReadWrite.All) and one that can read
the user — Graph documents User.EnableDisableAccount.All + User.Read.All as the
least-privileged combination, while User.ReadWrite.All / Directory.ReadWrite.All carry both
on their own. Also requires a supporting Entra role (e.g. User Administrator).

## EXAMPLES

### Example 1
```powershell
Disable-GkStaleUser -UserId ada@contoso.com
```
Block one user (prompts for confirmation).

### Example 2
```powershell
Get-GkStaleUser -InactiveDays 180 | Where-Object { -not $_.IsGuest } | Disable-GkStaleUser -WhatIf
```
Preview blocking every non-guest user stale 180+ days, without making changes.

### Example 3
```powershell
Get-GkStaleUser -InactiveDays 365 | Disable-GkStaleUser -Confirm:$false |
    Where-Object Outcome -eq 'Failed'
```
Block without prompting and inspect any failures.

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
### PSGraphKit.UserDisableResult
