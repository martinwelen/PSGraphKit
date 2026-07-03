# Get-GkSecureScore

## SYNOPSIS
Report the tenant's latest Microsoft Secure Score, or the per-control breakdown.

## SYNTAX
```
Get-GkSecureScore [-IncludeControls] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /security/secureScores and returns the most recent score with the current/max
values and a computed percentage. With -IncludeControls it instead returns one row per
control in that score (name, category, score, status) so you can see where points are lost.

Requires the SecurityEvents.Read.All scope. Secure Score is fed by Microsoft 365 / Defender
products; no extra Entra license is needed to read it.

## EXAMPLES

### Example 1
```powershell
Get-GkSecureScore
```
The latest overall Secure Score and percentage.

### Example 2
```powershell
Get-GkSecureScore -IncludeControls | Sort-Object Score | Select-Object -First 15
```
The 15 controls contributing the fewest points (improvement opportunities).

### Example 3
```powershell
Get-GkSecureScore -AsReport | Export-Csv .\secure-score.csv -NoTypeInformation
```

## PARAMETERS

### -IncludeControls
Return the per-control breakdown of the latest score instead of the summary.

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
### PSGraphKit.SecureScore or PSGraphKit.SecureScoreControl
