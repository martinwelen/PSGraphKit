# Get-GkConditionalAccessTemplate

## SYNOPSIS
Report Microsoft's built-in Conditional Access policy templates.

## SYNTAX
```
Get-GkConditionalAccessTemplate [[-Scenario] <string>] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /identity/conditionalAccess/templates — Microsoft's recommended CA policy
templates, grouped by scenario (secureFoundation, zeroTrust, protectAdmins, remoteWork,
emergingThreats). Useful as a baseline to compare a tenant's existing policies against and
to spot missing coverage.

Requires Policy.Read.All.

## EXAMPLES

### Example 1
```powershell
Get-GkConditionalAccessTemplate
```
All CA templates with their scenarios.

### Example 2
```powershell
Get-GkConditionalAccessTemplate -Scenario protectAdmins
```
Templates aimed at protecting administrators.

### Example 3
```powershell
Get-GkConditionalAccessTemplate -AsReport | Export-Csv .\ca-templates.csv -NoTypeInformation
```

## PARAMETERS

### -Scenario
Filter to templates tagged with a scenario (e.g. protectAdmins).

```yaml
Type: String
Required: false
Position: 1
Default value: None
Accept pipeline input: false
```

### -AsReport
Flatten Scenarios to a '; '-joined string and add ReportGeneratedUtc.

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
### PSGraphKit.CaTemplate
