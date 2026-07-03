# Get-GkSignInReport

## SYNOPSIS
Report Entra sign-ins over a recent window, with risk and Conditional Access status.

## SYNTAX
```
Get-GkSignInReport [[-Days] <int>] [[-UserPrincipalName] <string>] [-FailedOnly] [-RiskyOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /auditLogs/signIns filtered to the last -Days (a date filter is required by the
API in practice). Returns interactive sign-ins with status, failure reason, risk, CA status,
IP, and client app.

Requires a Microsoft Entra ID P1 or P2 license and the AuditLog.Read.All scope (add
Policy.Read.All to populate applied CA policy detail). Risk fields require P2. Standard
sign-in log retention is ~7 days (free) / ~30 days (P1/P2). Unavailable data warns and
returns nothing rather than failing.

## EXAMPLES

### Example 1
```powershell
Get-GkSignInReport -Days 3 -FailedOnly | Group-Object UserPrincipalName | Sort-Object Count -Descending
```
Failed sign-ins in the last 3 days, grouped by user.

### Example 2
```powershell
Get-GkSignInReport -RiskyOnly -Days 7
```
Risky sign-ins in the last week.

### Example 3
```powershell
Get-GkSignInReport -UserPrincipalName ada@contoso.com -Days 1
```
One user's sign-ins in the last day.

## PARAMETERS

### -Days
Look-back window in days (default 7).

```yaml
Type: Int32
Required: false
Position: 1
Default value: 7
Accept pipeline input: false
```

### -UserPrincipalName
Filter to a single user's sign-ins.

```yaml
Type: String
Required: false
Position: 2
Default value: None
Accept pipeline input: false
```

### -FailedOnly
Return only failed sign-ins.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -RiskyOnly
Return only sign-ins with a non-none aggregated risk level (P2).

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
### PSGraphKit.SignIn
