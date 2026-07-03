# Remove-GkGroupMember

## SYNOPSIS
Remove a member from one or more groups.

## SYNTAX
```
Remove-GkGroupMember [-GroupId] <string[]> [-MemberId] <string> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Removes the specified directory object from a group's membership
(DELETE /groups/{id}/members/{memberId}/$ref) — this removes only the membership link, not
the object itself.

State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts group IDs from the
pipeline and yields a PSGraphKit.GroupMemberResult per group; failures warn and continue.
Requires GroupMember.ReadWrite.All (role-assignable groups also need
RoleManagement.ReadWrite.Directory).

## EXAMPLES

### Example 1
```powershell
Remove-GkGroupMember -GroupId $groupId -MemberId $userId
```
Remove one member (prompts for confirmation).

### Example 2
```powershell
Remove-GkGroupMember -GroupId $groupId -MemberId $userId -WhatIf
```
Preview the removal.

### Example 3
```powershell
$groups | Remove-GkGroupMember -MemberId $userId -Confirm:$false | Where-Object Outcome -eq 'Failed'
```

## PARAMETERS

### -GroupId
One or more group object IDs. Accepts pipeline input (incl. by the Id property).

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -MemberId
Object ID of the member to remove.

```yaml
Type: String
Required: true
Position: 2
Default value: None
Accept pipeline input: false
```

### CommonParameters
This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, -WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. For more information, see about_CommonParameters.

## INPUTS
### None

## OUTPUTS
### PSGraphKit.GroupMemberResult
