# Get-GkGroupExpirationPolicy

## SYNOPSIS
Report the Microsoft 365 group expiration (lifecycle) policy, if one is configured.

## SYNTAX
```
Get-GkGroupExpirationPolicy [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /groupLifecyclePolicies. Returns the configured group-lifetime, which group types
it applies to, and the alternate notification emails. If no policy is configured the result is
empty (M365 groups then never auto-expire). Requires the Directory.Read.All scope.

## EXAMPLES

### Example 1
```powershell
Get-GkGroupExpirationPolicy
```
The M365 group expiration policy (empty output = none configured).

### Example 2
```powershell
if (-not (Get-GkGroupExpirationPolicy)) { 'No M365 group expiration policy configured.' }
```

### Example 3
```powershell
Get-GkGroupExpirationPolicy -AsReport | Export-Csv .\group-expiration.csv -NoTypeInformation
```

## PARAMETERS

### -AsReport
Flatten AlternateNotificationEmails to a '; '-joined string and add ReportGeneratedUtc.

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
### PSGraphKit.GroupExpirationPolicy
