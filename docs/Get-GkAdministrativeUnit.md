# Get-GkAdministrativeUnit

## SYNOPSIS
Report administrative units with membership type, visibility, and member count.

## SYNTAX
```
Get-GkAdministrativeUnit [-SkipMemberCount] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /directory/administrativeUnits and, per unit, the member count
(/administrativeUnits/{id}/members with $count). Dynamic-membership units also show their
rule.

Requires AdministrativeUnit.Read.All. Member counting is one call per unit; use
-SkipMemberCount to omit it.

## EXAMPLES

### Example 1
```powershell
Get-GkAdministrativeUnit | Sort-Object MemberCount -Descending
```
Administrative units by size.

### Example 2
```powershell
Get-GkAdministrativeUnit | Where-Object MembershipType -eq 'Dynamic'
```
Dynamic administrative units (with their rules).

### Example 3
```powershell
Get-GkAdministrativeUnit -SkipMemberCount -AsReport | Export-Csv .\admin-units.csv -NoTypeInformation
```

## PARAMETERS

### -SkipMemberCount
Do not fetch per-unit member counts (MemberCount will be $null).

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
### PSGraphKit.AdministrativeUnit
