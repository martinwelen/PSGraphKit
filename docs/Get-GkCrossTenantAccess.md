# Get-GkCrossTenantAccess

## SYNOPSIS
Report cross-tenant access (B2B) settings: the default policy and any partner overrides.

## SYNTAX
```
Get-GkCrossTenantAccess [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /policies/crossTenantAccessPolicy/default and /partners, and emits one row for the
default plus one per configured partner, summarizing the inbound trust settings (whether MFA,
compliant-device, and hybrid-joined claims from the partner are trusted).

Requires Policy.Read.All. (Full identity-synchronization detail needs a higher role and is
not surfaced here.)

## EXAMPLES

### Example 1
```powershell
Get-GkCrossTenantAccess
```
The default cross-tenant policy and any partner-specific configurations.

### Example 2
```powershell
Get-GkCrossTenantAccess | Where-Object { $_.Scope -ne 'Default' }
```
Only partner-specific overrides.

### Example 3
```powershell
Get-GkCrossTenantAccess -AsReport | Export-Csv .\cross-tenant.csv -NoTypeInformation
```

## PARAMETERS

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
### PSGraphKit.CrossTenantAccess
