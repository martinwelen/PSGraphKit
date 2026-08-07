# Get-GkGroupMember

## SYNOPSIS
List the members of a group, classified by object type.

## SYNTAX
```
Get-GkGroupMember [-GroupId] <string[]> [[-MemberType] <string>] [[-First] <int>] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /groups/{id}/members and returns one row per member with its directory object
type resolved (user, group, servicePrincipal, device, orgContact). This is the read
companion to Add-GkGroupMember / Remove-GkGroupMember, and pairs with Get-GkGroupReport —
which reports member *counts* — when you need the actual names.

Members are direct members only; nested group membership is not expanded. Requires
GroupMember.Read.All (or a broader group/directory read scope).

## EXAMPLES

### Example 1
```powershell
Get-GkGroupMember -GroupId $groupId
```
List every member of one group.

### Example 2
```powershell
Get-GkGroupReport -OwnerlessOnly | Get-GkGroupMember -MemberType User
```
List the users in every ownerless group.

### Example 3
```powershell
Get-GkGroupMember -GroupId $id -AsReport | Export-Csv .\members.csv -NoTypeInformation
```

## PARAMETERS

### -GroupId
One or more group object IDs. Accepts pipeline input, including by the Id / GroupId
property so Get-GkGroupReport output can be piped in.

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -MemberType
Only return members of this directory object type. Defaults to All.

```yaml
Type: String
Required: false
Position: 2
Default value: All
Accept pipeline input: false
```

### -First
Return at most this many members per group.

```yaml
Type: Int32
Required: false
Position: 3
Default value: 0
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
### PSGraphKit.GroupMember
