# Get-GkUserAccessReport

## SYNOPSIS
Report a single user's full access footprint: group memberships, directory roles,
licenses, and application role assignments.

## SYNTAX
```
Get-GkUserAccessReport [-UserId] <string[]> [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
For each user, gathers:
  * Identity           GET /users/{id}
  * Groups & roles     GET /users/{id}/transitiveMemberOf  (classified by type)
  * App assignments    GET /users/{id}/appRoleAssignments
  * Licenses           GET /users/{id}/licenseDetails
and returns one object per user with the collections plus counts.

Because licenseDetails has no application permission, this cmdlet requires a DELEGATED
session; Test-GkConnection blocks app-only sessions. Individual facets that fail (e.g. a
denied sub-resource) warn and continue so the rest of the report still returns. A user id
that cannot be resolved is skipped with a warning.

## EXAMPLES

### Example 1
```powershell
Get-GkUserAccessReport -UserId ada@contoso.com
```
Full access footprint for one user.

### Example 2
```powershell
'ada@contoso.com','bob@contoso.com' | Get-GkUserAccessReport -AsReport |
    Export-Csv .\access.csv -NoTypeInformation
```
Footprints for several users, flattened for export.

### Example 3
```powershell
Get-GkAdminRoleAssignment -AssignmentKind Active |
    Select-Object -ExpandProperty PrincipalId -Unique |
    Get-GkUserAccessReport
```
Pipe the principals holding active roles into a full access report.

## PARAMETERS

### -UserId
One or more user object IDs or userPrincipalNames. Accepts pipeline input (including by the
UserPrincipalName/Id property, so output of other cmdlets can be piped in).

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -AsReport
Flatten the Groups/DirectoryRoles/Licenses/AppRoleAssignments collections to '; '-joined
strings and add ReportGeneratedUtc for clean export.

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
### PSGraphKit.UserAccessReport
