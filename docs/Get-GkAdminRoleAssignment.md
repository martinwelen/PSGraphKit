# Get-GkAdminRoleAssignment

## SYNOPSIS
Report Entra directory role assignments — active, PIM-eligible, and PIM active/time-bound —
with the assigned principal and role resolved.

## SYNTAX
```
Get-GkAdminRoleAssignment [[-AssignmentKind] <string>] [[-RoleName] <string>] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Uses the modern role-management (RBAC) API rather than the legacy directoryRoles surface:
  * Active         GET /roleManagement/directory/roleAssignments
  * Eligible (PIM)  GET /roleManagement/directory/roleEligibilityScheduleInstances
  * Time-bound (PIM) GET /roleManagement/directory/roleAssignmentScheduleInstances
Each is expanded with principal and roleDefinition. Rows are tagged with AssignmentKind
(Active | Eligible | TimeBound) and include the directory scope (/ = tenant-wide).

PIM (eligible/time-bound) data requires Microsoft Entra ID P2 / Governance. If those
endpoints are unavailable (no P2) they are skipped with a warning and active assignments
are still returned (degrade mode: warn and continue).

## EXAMPLES

### Example 1
```powershell
Get-GkAdminRoleAssignment
```
All active, eligible, and time-bound role assignments in the tenant.

### Example 2
```powershell
Get-GkAdminRoleAssignment -AssignmentKind Eligible -RoleName '*Administrator*'
```
PIM-eligible assignments to any *Administrator* role.

### Example 3
```powershell
Get-GkAdminRoleAssignment |
    Group-Object RoleName |
    Sort-Object Count -Descending |
    Select-Object Name, Count
```
Count of assignments per role, most-assigned first.

## PARAMETERS

### -AssignmentKind
Which assignment kinds to return: All (default), Active, Eligible, or TimeBound.

```yaml
Type: String
Required: false
Position: 1
Default value: All
Accept pipeline input: false
```

### -RoleName
Client-side wildcard filter on the role display name (e.g. '*Admin*').

```yaml
Type: String
Required: false
Position: 2
Default value: None
Accept pipeline input: false
```

### -AsReport
Add a ReportGeneratedUtc column for clean export.

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
### PSGraphKit.AdminRoleAssignment
