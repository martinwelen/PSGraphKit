# Get-GkCustomRole

## SYNOPSIS
Report custom (non-built-in) directory role definitions and their permissions.

## SYNTAX
```
Get-GkCustomRole [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /roleManagement/directory/roleDefinitions filtered to isBuiltIn eq false, and
returns each custom role with whether it is enabled and the resource actions it grants.

Requires RoleManagement.Read.Directory.

## EXAMPLES

### Example 1
```powershell
Get-GkCustomRole
```
All custom directory roles with their allowed actions.

### Example 2
```powershell
Get-GkCustomRole | Where-Object { -not $_.IsEnabled }
```
Custom roles that are defined but disabled.

### Example 3
```powershell
Get-GkCustomRole -AsReport | Export-Csv .\custom-roles.csv -NoTypeInformation
```

## PARAMETERS

### -AsReport
Flatten Permissions to a '; '-joined string and add ReportGeneratedUtc.

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
### PSGraphKit.CustomRole
