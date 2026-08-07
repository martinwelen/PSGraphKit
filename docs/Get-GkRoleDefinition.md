# Get-GkRoleDefinition

## SYNOPSIS
List directory role definitions — built-in and custom — with their permission counts.

## SYNTAX
```
Get-GkRoleDefinition [[-Name] <string>] [[-Scope] <string>] [-IncludePermission] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /roleManagement/directory/roleDefinitions and returns every role the tenant can
assign, so you can answer "what does this role actually allow" without leaving the shell.
Get-GkCustomRole covers only the custom roles; this is the full catalogue, and it is the
lookup behind the role names reported by Get-GkAdminRoleAssignment.

Requires RoleManagement.Read.Directory (or Directory.Read.All).

## EXAMPLES

### Example 1
```powershell
Get-GkRoleDefinition -Name 'administrator' | Sort-Object DisplayName
```
Every role with "administrator" in its name.

### Example 2
```powershell
Get-GkRoleDefinition -Scope Custom -IncludePermission
```
Custom roles with the actions they grant.

### Example 3
```powershell
Get-GkRoleDefinition -AsReport | Export-Csv .\roles.csv -NoTypeInformation
```

## PARAMETERS

### -Name
Only return roles whose display name contains this text (case-insensitive).

```yaml
Type: String
Required: false
Position: 1
Default value: None
Accept pipeline input: false
```

### -Scope
Only return built-in roles, only custom roles, or all. Defaults to All.

```yaml
Type: String
Required: false
Position: 2
Default value: All
Accept pipeline input: false
```

### -IncludePermission
Add a Permissions column listing the allowed resource actions. These lists are long, so
they are omitted by default.

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
### PSGraphKit.RoleDefinition
