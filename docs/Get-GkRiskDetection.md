# Get-GkRiskDetection

## SYNOPSIS
Report Microsoft Entra ID Protection risk detections (e.g. impossible travel, leaked
credentials, anonymous IP).

## SYNTAX
```
Get-GkRiskDetection [[-RiskLevel] <string>] [[-First] <int>] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /identityProtection/riskDetections. Requires the IdentityRiskEvent.Read.All scope
and a Microsoft Entra ID P1 or P2 license (P2 gives full detail). When unavailable, warns and
returns nothing.

## EXAMPLES

### Example 1
```powershell
Get-GkRiskDetection | Sort-Object DetectedDateTime -Descending | Select-Object -First 20
```
The 20 most recent risk detections.

### Example 2
```powershell
Get-GkRiskDetection -RiskLevel high | Group-Object RiskEventType
```
High-risk detections grouped by type.

### Example 3
```powershell
Get-GkRiskDetection -AsReport | Export-Csv .\risk-detections.csv -NoTypeInformation
```

## PARAMETERS

### -RiskLevel
Filter to a single risk level: low, medium, or high.

```yaml
Type: String
Required: false
Position: 1
Default value: None
Accept pipeline input: false
```

### -First
Return at most N risk detections, stopping pagination early. Use to bound the pull on a large
tenant instead of paging the entire riskDetections collection.

```yaml
Type: Int32
Required: false
Position: 2
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
### PSGraphKit.RiskDetection
