# Get-GkServiceHealth

## SYNOPSIS
Report the current health of each Microsoft 365 service, with active incidents.

## SYNTAX
```
Get-GkServiceHealth [[-Service] <string>] [-UnhealthyOnly] [-IncludeIssue] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /admin/serviceAnnouncement/healthOverviews for the per-service status, and with
-IncludeIssue also pulls the open issues behind any service that is not healthy. This is the
"is it us or is it Microsoft" check — worth running before you start debugging a tenant.

Requires the ServiceHealth.Read.All scope, which is the only permission Graph accepts for
this API.

## EXAMPLES

### Example 1
```powershell
Get-GkServiceHealth -UnhealthyOnly
```
Only the services currently degraded or in incident.

### Example 2
```powershell
Get-GkServiceHealth -UnhealthyOnly -IncludeIssue
```
Degraded services with the incidents behind them.

### Example 3
```powershell
Get-GkServiceHealth -AsReport | Export-Csv .\service-health.csv -NoTypeInformation
```

## PARAMETERS

### -Service
Only return services whose name contains this text (case-insensitive), e.g. 'Exchange'.

```yaml
Type: String
Required: false
Position: 1
Default value: None
Accept pipeline input: false
```

### -UnhealthyOnly
Only return services that are not reporting serviceOperational.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -IncludeIssue
Add the open issues for each returned service. Costs one extra Graph call.

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
### PSGraphKit.ServiceHealth
