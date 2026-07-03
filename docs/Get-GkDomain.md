# Get-GkDomain

## SYNOPSIS
Report the tenant's domains with verification status and authentication (managed/federated)
type.

## SYNTAX
```
Get-GkDomain [-FederatedOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /domains. Federated domains are worth flagging in an assessment (external IdP trust).
Requires the Domain.Read.All scope.

## EXAMPLES

### Example 1
```powershell
Get-GkDomain
```
All domains with verification and authentication type.

### Example 2
```powershell
Get-GkDomain -FederatedOnly
```
Only federated domains.

### Example 3
```powershell
Get-GkDomain -AsReport | Export-Csv .\domains.csv -NoTypeInformation
```

## PARAMETERS

### -FederatedOnly
Return only federated domains.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AsReport
Flatten SupportedServices to a '; '-joined string and add ReportGeneratedUtc.

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
### PSGraphKit.Domain
