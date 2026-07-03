# Remove-GkAdminRoleAssignment

## SYNOPSIS
Remove a directory role assignment — direct active, PIM-eligible, or PIM active.

## SYNTAX
```
Remove-GkAdminRoleAssignment [-AssignmentKind] <string> [[-AssignmentId] <string>] [[-PrincipalId] <string>] [[-RoleDefinitionId] <string>] [[-Scope] <string>] [[-RoleName] <string>] [[-Justification] <string>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Removes the assignment using the correct path for its kind (as reported by
Get-GkAdminRoleAssignment, which this cmdlet is designed to accept from the pipeline):
  * Active     DELETE /roleManagement/directory/roleAssignments/{AssignmentId}
  * Eligible   POST /roleManagement/directory/roleEligibilityScheduleRequests (action=adminRemove)
  * TimeBound  POST /roleManagement/directory/roleAssignmentScheduleRequests (action=adminRemove)

State-changing: supports -WhatIf / -Confirm and prompts by default. Yields a
PSGraphKit.RoleRemovalResult per assignment; failures warn and continue. Graph refuses to
remove the caller's own Global Administrator assignment. Requires
RoleManagement.ReadWrite.Directory plus the Privileged Role Administrator role.

## EXAMPLES

### Example 1
```powershell
Get-GkAdminRoleAssignment -AssignmentKind Eligible -RoleName '*Administrator*' |
    Remove-GkAdminRoleAssignment -WhatIf
```
Preview removing every eligible *Administrator* assignment.

### Example 2
```powershell
Get-GkAdminRoleAssignment | Where-Object PrincipalName -eq 'Ada Admin' |
    Remove-GkAdminRoleAssignment -Confirm:$false
```
Remove all of one principal's assignments.

### Example 3
```powershell
Remove-GkAdminRoleAssignment -AssignmentKind Active -AssignmentId $id -RoleName 'Helpdesk Administrator'
```
Remove one active assignment by id (prompts for confirmation).

## PARAMETERS

### -AssignmentKind
Active, Eligible, or TimeBound (bound from Get-GkAdminRoleAssignment output).

```yaml
Type: String
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByPropertyName)
```

### -AssignmentId
The roleAssignment id (required for Active removals).

```yaml
Type: String
Required: false
Position: 2
Default value: None
Accept pipeline input: true (ByPropertyName)
```

### -PrincipalId
Principal id (required for PIM Eligible/TimeBound removals).

```yaml
Type: String
Required: false
Position: 3
Default value: None
Accept pipeline input: true (ByPropertyName)
```

### -RoleDefinitionId
Role definition id (required for PIM Eligible/TimeBound removals).

```yaml
Type: String
Required: false
Position: 4
Default value: None
Accept pipeline input: true (ByPropertyName)
```

### -Scope
Directory scope id ('/' = tenant). Defaults to '/'.

```yaml
Type: String
Required: false
Position: 5
Default value: None
Accept pipeline input: true (ByPropertyName)
```

### -RoleName
Role display name, used only for confirmation/output messages.

```yaml
Type: String
Required: false
Position: 6
Default value: None
Accept pipeline input: true (ByPropertyName)
```

### -Justification
Justification recorded on PIM removal requests.

```yaml
Type: String
Required: false
Position: 7
Default value: Removed via PSGraphKit
Accept pipeline input: false
```

### CommonParameters
This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, -WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. For more information, see about_CommonParameters.

## INPUTS
### None

## OUTPUTS
### PSGraphKit.RoleRemovalResult
