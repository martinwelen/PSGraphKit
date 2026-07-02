# Get-GkGuestInventory

## SYNOPSIS
Inventory guest (external) accounts with their sponsor, invitation state, last sign-in,
and inactivity/age in days.

## SYNTAX
```
Get-GkGuestInventory [[-InactiveDays] <int>] [-StaleOnly] [-SkipSponsor] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Lists users where userType eq 'Guest' (GET /users) and, for each, reports the invitation
state (externalUserState), when it last changed, the account age from createdDateTime, and
the inactivity age derived from signInActivity. By default it also resolves each guest's
sponsor(s) via GET /users/{id}/sponsors — one call per guest; use -SkipSponsor to skip that
on large tenants.

Sponsor reads depend on the signed-in admin's directory role in delegated sessions; if a
sponsor lookup is denied, the guest is still returned (Sponsors empty) and a single warning
is emitted afterward (degrade mode: warn and continue).

Reading signInActivity requires Entra ID P1/P2 + AuditLog.Read.All; without it, guests
appear as never-signed-in.

## EXAMPLES

### Example 1
```powershell
Get-GkGuestInventory
```
All guests with sponsor, invitation state, age, and inactivity.

### Example 2
```powershell
Get-GkGuestInventory -StaleOnly -InactiveDays 180 |
    Sort-Object InactiveDays -Descending
```
Guests inactive for 180+ days (or never signed in), most inactive first.

### Example 3
```powershell
Get-GkGuestInventory -SkipSponsor -AsReport |
    Export-Csv .\guests.csv -NoTypeInformation
```
Fast guest export (no sponsor lookups), sponsors column flattened for CSV.

## PARAMETERS

### -InactiveDays
Threshold in days used to set the IsStale flag (default 90). Never-signed-in guests are stale.

```yaml
Type: Int32
Required: false
Position: 1
Default value: 90
Accept pipeline input: false
```

### -StaleOnly
Return only guests flagged stale (inactive >= InactiveDays, or never signed in).

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -SkipSponsor
Do not resolve sponsors (skips the per-guest /sponsors call). Sponsors will be empty.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AsReport
Flatten Sponsors to a single '; '-joined string and add ReportGeneratedUtc for clean export.

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
### PSGraphKit.GuestInventory
