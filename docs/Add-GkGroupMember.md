# Add-GkGroupMember

## SYNOPSIS
Add a member (user, group, or service principal) to one or more groups.

## SYNTAX
```
Add-GkGroupMember [-GroupId] <string[]> [-MemberId] <string> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Adds the specified directory object as a member (POST /groups/{id}/members/$ref).

State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts group IDs from the
pipeline and yields a PSGraphKit.GroupMemberResult per group; failures warn and continue
(adding an existing member returns a Graph error). Requires GroupMember.ReadWrite.All. Adding
a member to a role-assignable group additionally requires RoleManagement.ReadWrite.Directory.

## EXAMPLES

### Example 1
```powershell
Add-GkGroupMember -GroupId $groupId -MemberId $userId
```
Add one member (prompts for confirmation).

### Example 2
```powershell
Get-GkGroupReport | Where-Object DisplayName -eq 'All Staff' | Add-GkGroupMember -MemberId $userId -Confirm:$false
```
Add a user to a group selected from a report.

### Example 3
```powershell
Add-GkGroupMember -GroupId $groupId -MemberId $userId -WhatIf
```
Preview the change.

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
Object ID of the user, group, or service principal to add.

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
