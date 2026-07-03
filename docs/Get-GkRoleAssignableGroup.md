# Get-GkRoleAssignableGroup

## SYNOPSIS
Report role-assignable ("privileged") groups and their owners, flagging ownerless ones.

## SYNTAX
```
Get-GkRoleAssignableGroup [-OwnerlessOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /groups filtered to isAssignableToRole eq true. These groups can be granted
directory roles, so their owners and members are effectively privileged — a common
assessment focus ("privileged unprotected groups"). Owners are resolved per group and
ownerless groups are flagged.

Requires Group.Read.All. Uses the ConsistencyLevel: eventual advanced-query header.

## EXAMPLES

### Example 1
```powershell
Get-GkRoleAssignableGroup
```
All role-assignable groups with owners and ownerless flag.

### Example 2
```powershell
Get-GkRoleAssignableGroup -OwnerlessOnly
```
Privileged groups nobody owns — a governance gap.

### Example 3
```powershell
Get-GkRoleAssignableGroup -AsReport | Export-Csv .\role-assignable-groups.csv -NoTypeInformation
```

## PARAMETERS

### -OwnerlessOnly
Return only role-assignable groups that have no owners.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AsReport
Flatten Owners to a '; '-joined string and add ReportGeneratedUtc.

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
### PSGraphKit.RoleAssignableGroup
