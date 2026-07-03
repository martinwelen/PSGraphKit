# Get-GkSubscription

## SYNOPSIS
Report tenant subscriptions with their renewal/expiry date and status.

## SYNTAX
```
Get-GkSubscription [[-ExpiringInDays] <int>] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /directory/subscriptions (companySubscription), which — unlike /subscribedSkus —
includes the lifecycle date. nextLifecycleDateTime is the next renewal/expiry, so this fills
the "when do our licenses lapse" gap. Requires the Organization.Read.All scope.

## EXAMPLES

### Example 1
```powershell
Get-GkSubscription | Sort-Object NextLifecycleDate
```
Subscriptions by upcoming renewal/expiry.

### Example 2
```powershell
Get-GkSubscription -ExpiringInDays 60
```
Subscriptions renewing or expiring within 60 days.

### Example 3
```powershell
Get-GkSubscription -AsReport | Export-Csv .\subscriptions.csv -NoTypeInformation
```

## PARAMETERS

### -ExpiringInDays
Only return subscriptions whose next lifecycle date is within this many days (e.g. 60).

```yaml
Type: Int32
Required: false
Position: 1
Default value: 0
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
### PSGraphKit.Subscription
