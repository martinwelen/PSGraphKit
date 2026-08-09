# Restore-GkDeletedObject

## SYNOPSIS
Restore a soft-deleted directory object from the 30-day recycle window.

## SYNTAX
```
Restore-GkDeletedObject [-Id] <string[]> [-Type] <string> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Calls POST /directory/deletedItems/{id}/restore. This is the write counterpart to
Get-GkDeletedItem, and the recovery path for anything Remove-GkStaleGuest -Delete or
Disable-GkStaleDevice -Delete removed by mistake.

Restoring a user also restores their mailbox, license assignments and group memberships.
A user whose userPrincipalName or proxy addresses now collide with a live object cannot be
restored until the conflict is resolved — Graph rejects it, and the error says which.

State-changing: supports -WhatIf / -Confirm and prompts by default.

Scopes depend on the object type and only the one in use is validated:
User.DeleteRestore.All for users, Group.ReadWrite.All for groups,
Application.ReadWrite.All for applications and service principals,
AdministrativeUnit.ReadWrite.All for administrative units.

## EXAMPLES

### Example 1
```powershell
Get-GkDeletedItem -Type User -ExpiringInDays 3 | Restore-GkDeletedObject -WhatIf
```
Preview restoring every deleted user about to be purged.

### Example 2
```powershell
Restore-GkDeletedObject -Id $objectId -Type User
```
Restore one user (prompts for confirmation).

### Example 3
```powershell
Get-GkDeletedItem -Type Group | Where-Object DisplayName -like 'Project*' |
    Restore-GkDeletedObject -Confirm:$false
```

## PARAMETERS

### -Id
One or more deleted object IDs. Accepts pipeline input, including by the Id property so
Get-GkDeletedItem output can be piped straight in.

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -Type
The directory object type being restored. Determines which scope is validated. Accepts
pipeline input by the ObjectType property, so Get-GkDeletedItem supplies it automatically.

```yaml
Type: String
Required: true
Position: 2
Default value: None
Accept pipeline input: true (ByPropertyName)
```

### CommonParameters
This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, -WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. For more information, see about_CommonParameters.

## INPUTS
### None

## OUTPUTS
### PSGraphKit.RestoreResult
