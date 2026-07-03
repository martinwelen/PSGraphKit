# Get-GkNamedLocation

## SYNOPSIS
Report Conditional Access named locations (IP ranges and countries).

## SYNTAX
```
Get-GkNamedLocation [-TrustedOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /identity/conditionalAccess/namedLocations, a heterogeneous collection of
ipNamedLocation (with isTrusted and CIDR ranges) and countryNamedLocation (with a country
list). Ranges/countries are flattened for reporting.

Requires Policy.Read.All.

## EXAMPLES

### Example 1
```powershell
Get-GkNamedLocation
```
All named locations with their type and ranges/countries.

### Example 2
```powershell
Get-GkNamedLocation -TrustedOnly
```
Only trusted IP locations.

### Example 3
```powershell
Get-GkNamedLocation -AsReport | Export-Csv .\named-locations.csv -NoTypeInformation
```

## PARAMETERS

### -TrustedOnly
Return only trusted IP named locations.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AsReport
Flatten IpRanges/Countries to '; '-joined strings and add ReportGeneratedUtc.

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
### PSGraphKit.NamedLocation
