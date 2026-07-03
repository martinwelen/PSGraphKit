# Remove-GkStaleGuest

## SYNOPSIS
Disable (default) or delete stale guest accounts, with a guest-type safety check.

## SYNTAX
```
Remove-GkStaleGuest [-UserId] <string[]> [-Delete] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
By default blocks sign-in (PATCH /users/{id} accountEnabled=false). With -Delete it instead
deletes the account (DELETE /users/{id}); deletion is a 30-day soft-delete, recoverable from
the directory's deleted items. Permanent purge is intentionally NOT offered here — do it
deliberately.

Safety: unless -Force is given, each account is verified to be a guest (userType eq 'Guest')
before any change, and members are skipped with a warning — so piping the wrong objects in
cannot accidentally disable/delete a member.

State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts users from the
pipeline and yields a PSGraphKit.GuestRemovalResult per user; failures warn and continue.
Requires User.ReadWrite.All (or Directory.ReadWrite.All) plus a supporting Entra role.

## EXAMPLES

### Example 1
```powershell
Get-GkGuestInventory -StaleOnly -InactiveDays 180 | Remove-GkStaleGuest -WhatIf
```
Preview disabling guests inactive 180+ days.

### Example 2
```powershell
Get-GkGuestInventory -StaleOnly -InactiveDays 365 | Remove-GkStaleGuest -Delete -Confirm:$false
```
Soft-delete guests inactive 365+ days.

### Example 3
```powershell
Remove-GkStaleGuest -UserId guest_ext#EXT#@contoso.onmicrosoft.com
```
Disable one guest (prompts for confirmation).

## PARAMETERS

### -UserId
One or more user object IDs or userPrincipalNames (accepts pipeline input, incl. by the
UserPrincipalName / Id property).

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -Delete
Delete the account (soft-delete) instead of only disabling it.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -Force
Skip the guest-type safety check (act on the user regardless of userType).

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
### PSGraphKit.GuestRemovalResult
