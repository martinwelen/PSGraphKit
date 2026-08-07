# Get-GkStaleUser

## SYNOPSIS
Report users with no sign-in activity for a threshold number of days, flagging disabled
and guest accounts.

## SYNTAX
```
Get-GkStaleUser [[-InactiveDays] <int>] [[-UserType] <string>] [-IncludeAll] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /users with the signInActivity property and computes staleness from the most
recent interactive OR non-interactive sign-in. Users who have never signed in are treated
as stale. Each result is flagged for account state (AccountEnabled) and guest status.

Reading signInActivity requires a Microsoft Entra ID P1 or P2 license and the
AuditLog.Read.All permission. When the tenant lacks the license, Graph returns no
signInActivity data; every user then appears as "never signed in" and a warning is
emitted so the result is not misread. (Degrade mode: warn and continue.)

Notes on the sign-in timestamps (per Microsoft Graph):
  * LastSignIn            = last interactive sign-in (success or failure).
  * LastNonInteractiveSignIn = last non-interactive sign-in.
  * LastSuccessfulSignIn  = last successful sign-in; only populated from 2023-12-01 and
    not backfilled, so it is reported but not used as the primary staleness signal.
LastActivity is the most recent of the interactive and non-interactive timestamps.

## EXAMPLES

### Example 1
```powershell
Get-GkStaleUser -InactiveDays 120
```
Users with no sign-in in the last 120 days (including never-signed-in), flagged.

### Example 2
```powershell
Get-GkStaleUser -UserType Guest -InactiveDays 60 |
    Where-Object AccountEnabled |
    Sort-Object InactiveDays -Descending
```
Enabled guest accounts stale for 60+ days, most inactive first.

### Example 3
```powershell
Get-GkStaleUser -InactiveDays 90 -AsReport |
    Export-Csv .\stale-users.csv -NoTypeInformation
```
Export a stale-user report with threshold/timestamp context columns.

## PARAMETERS

### -InactiveDays
Staleness threshold in days (default 90). A user is stale when their last sign-in is at
least this many days ago, or when they have never signed in.

```yaml
Type: Int32
Required: false
Position: 1
Default value: 90
Accept pipeline input: false
```

### -UserType
Limit to 'Member', 'Guest', or 'All' (default). A non-All value is applied server-side via a
userType filter (which combines fine with the signInActivity select).

```yaml
Type: String
Required: false
Position: 2
Default value: All
Accept pipeline input: false
```

### -IncludeAll
Return every user with the computed staleness fields, not just the stale ones.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AsReport
Add export-friendly context columns (StaleThresholdDays, ReportGeneratedUtc) for clean
Export-Csv / Export-Excel output.

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
### PSGraphKit.StaleUser
