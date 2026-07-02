# Get-GkCaPolicyReport

## SYNOPSIS
Report Conditional Access policies with their state and human-readable summaries of the
targeted users/apps and the grant/session controls.

## SYNTAX
```
Get-GkCaPolicyReport [[-State] <string>] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /identity/conditionalAccess/policies and flattens each policy's nested
conditions and controls into readable columns: who it targets (included/excluded users,
groups, roles), which apps, the client app types, the grant controls (e.g. "mfa AND
compliantDevice", or "Block"), and which session controls are enabled. The raw builtInControls
and enabled session-control names are kept as arrays for scripting.

Requires the Policy.Read.All scope.

## EXAMPLES

### Example 1
```powershell
Get-GkCaPolicyReport | Format-Table DisplayName, State, GrantControls
```
All CA policies with their state and grant controls.

### Example 2
```powershell
Get-GkCaPolicyReport -State Disabled
```
Policies that are currently switched off.

### Example 3
```powershell
Get-GkCaPolicyReport -AsReport | Export-Csv .\ca-policies.csv -NoTypeInformation
```

## PARAMETERS

### -State
Filter by state: All (default), Enabled, Disabled, or ReportOnly
(enabledForReportingButNotEnforced).

```yaml
Type: String
Required: false
Position: 1
Default value: All
Accept pipeline input: false
```

### -AsReport
Flatten the array columns (BuiltInControls, SessionControls, ClientAppTypes) to '; '-joined
strings and add ReportGeneratedUtc.

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
### PSGraphKit.CaPolicy
