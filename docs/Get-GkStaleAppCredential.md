# Get-GkStaleAppCredential

## SYNOPSIS
Report app credentials (secrets/certificates) that have never been used or are long unused.

## SYNTAX
```
Get-GkStaleAppCredential [[-InactiveDays] <int>] [-StaleOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /reports/appCredentialSignInActivities (beta) and reports the last time each app
credential authenticated, so unused secrets/certs can be removed. App display names are
resolved from /servicePrincipals.

BETA endpoint (no v1.0 equivalent), global-cloud only. Requires AuditLog.Read.All.
Unavailable data warns and returns nothing.

## EXAMPLES

### Example 1
```powershell
Get-GkStaleAppCredential | Where-Object NeverUsed
```
App credentials that have never authenticated — prime removal candidates.

### Example 2
```powershell
Get-GkStaleAppCredential -InactiveDays 180 -StaleOnly
```
Credentials unused for 180+ days.

### Example 3
```powershell
Get-GkStaleAppCredential -AsReport | Export-Csv .\stale-credentials.csv -NoTypeInformation
```

## PARAMETERS

### -InactiveDays
Staleness threshold in days (default 90).

```yaml
Type: Int32
Required: false
Position: 1
Default value: 90
Accept pipeline input: false
```

### -StaleOnly
Return only credentials that are stale (unused >= InactiveDays or never used).

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AsReport
Add a ReportGeneratedUtc column.

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
### PSGraphKit.StaleAppCredential
