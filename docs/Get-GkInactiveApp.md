# Get-GkInactiveApp

## SYNOPSIS
Report enterprise apps / service principals with no recent sign-in activity (decommission
candidates).

## SYNTAX
```
Get-GkInactiveApp [[-InactiveDays] <int>] [-StaleOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /reports/servicePrincipalSignInActivities (beta) and computes each service
principal's most recent activity across its delegated/application client and resource
sign-ins. Service principal display names are resolved from /servicePrincipals.

This report is on the Microsoft Graph BETA endpoint (no v1.0 equivalent) and is global-cloud
only. Requires AuditLog.Read.All. Unavailable data warns and returns nothing.

## EXAMPLES

### Example 1
```powershell
Get-GkInactiveApp -InactiveDays 180 -StaleOnly | Sort-Object InactiveDays -Descending
```
Enterprise apps unused for 180+ days.

### Example 2
```powershell
Get-GkInactiveApp | Where-Object NeverActive
```
Apps with no recorded sign-in activity at all.

### Example 3
```powershell
Get-GkInactiveApp -StaleOnly -AsReport | Export-Csv .\inactive-apps.csv -NoTypeInformation
```

## PARAMETERS

### -InactiveDays
Staleness threshold in days (default 90). An app is stale when its last activity is at least
this many days ago, or it has none recorded.

```yaml
Type: Int32
Required: false
Position: 1
Default value: 90
Accept pipeline input: false
```

### -StaleOnly
Return only stale apps (default returns all with the computed fields).

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
### PSGraphKit.InactiveApp
