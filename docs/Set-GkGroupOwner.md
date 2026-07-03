# Set-GkGroupOwner

## SYNOPSIS
Add an owner to one or more groups (e.g. to remediate ownerless groups).

## SYNTAX
```
Set-GkGroupOwner [-GroupId] <string[]> [-OwnerId] <string> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Calls POST /groups/{id}/owners/$ref to add the specified directory object (a user or service
principal) as an owner. Typically fed from Get-GkGroupReport -OwnerlessOnly to assign owners
to ownerless groups.

State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts groups from the
pipeline and yields a PSGraphKit.GroupOwnerResult per group; a failure warns and continues
(adding an existing owner returns a Graph error, reported as Failed). A group is limited to
100 owners. Owners cannot be set on groups synced from on-premises or created in Exchange.

Requires Group.ReadWrite.All (or Directory.ReadWrite.All) plus a supporting Entra role
(e.g. Groups Administrator or User Administrator).

## EXAMPLES

### Example 1
```powershell
Set-GkGroupOwner -GroupId 11111111-1111-1111-1111-111111111111 -OwnerId $adaId
```
Add an owner to one group (prompts for confirmation).

### Example 2
```powershell
Get-GkGroupReport -OwnerlessOnly | Where-Object GroupType -eq 'Microsoft365' |
    Set-GkGroupOwner -OwnerId $adminId -WhatIf
```
Preview assigning an owner to every ownerless Microsoft 365 group.

### Example 3
```powershell
Get-GkGroupReport -OwnerlessOnly | Set-GkGroupOwner -OwnerId $adminId -Confirm:$false |
    Where-Object Outcome -eq 'Failed'
```
Assign an owner to all ownerless groups without prompting and inspect any failures.

## PARAMETERS

### -GroupId
One or more group object IDs. Accepts pipeline input (incl. by the Id property, so
Get-GkGroupReport output pipes in directly).

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -OwnerId
Object ID of the user or service principal to add as an owner.

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
### PSGraphKit.GroupOwnerResult
