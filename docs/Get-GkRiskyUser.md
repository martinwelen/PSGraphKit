# Get-GkRiskyUser

## SYNOPSIS
Report users flagged by Microsoft Entra ID Protection with their risk level and state.

## SYNTAX
```
Get-GkRiskyUser [[-RiskLevel] <string>] [[-First] <int>] [-AtRiskOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /identityProtection/riskyUsers. Requires a Microsoft Entra ID P2 license and the
IdentityRiskyUser.Read.All scope. When unavailable (no P2), warns and returns nothing.

## EXAMPLES

### Example 1
```powershell
Get-GkRiskyUser -AtRiskOnly | Sort-Object RiskLevel -Descending
```
Users currently at risk, highest first.

### Example 2
```powershell
Get-GkRiskyUser -RiskLevel high
```
Only high-risk users.

### Example 3
```powershell
Get-GkRiskyUser -AsReport | Export-Csv .\risky-users.csv -NoTypeInformation
```

## PARAMETERS

### -RiskLevel
Filter to a single aggregated risk level: low, medium, or high.

```yaml
Type: String
Required: false
Position: 1
Default value: None
Accept pipeline input: false
```

### -First
Return at most N risky users, stopping pagination early. Use to bound the pull on a large
tenant instead of paging the entire riskyUsers collection.

```yaml
Type: Int32
Required: false
Position: 2
Default value: 0
Accept pipeline input: false
```

### -AtRiskOnly
Return only users whose riskState is atRisk or confirmedCompromised (excludes remediated /
dismissed).

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
### PSGraphKit.RiskyUser
