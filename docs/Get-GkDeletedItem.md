# Get-GkDeletedItem

## SYNOPSIS
List soft-deleted directory objects still inside the 30-day restore window.

## SYNTAX
```
Get-GkDeletedItem [-Type] <string> [[-DeletedWithinDays] <int>] [[-ExpiringInDays] <int>] [[-First] <int>] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /directory/deletedItems/microsoft.graph.{type} and reports what was deleted, when,
and how long is left to restore it. Deleted users, groups and applications sit in a
recoverable container for 30 days before Entra purges them permanently.

This is the safety net behind the module's delete paths: Remove-GkStaleGuest -Delete and
Disable-GkStaleDevice -Delete both soft-delete, so anything they removed by mistake shows up
here until the window closes.

Scopes depend on what you ask for and only the one in use is validated: User.Read.All for
users, Group.Read.All for groups, Application.Read.All for applications and service
principals, AdministrativeUnit.Read.All for administrative units.

## EXAMPLES

### Example 1
```powershell
Get-GkDeletedItem -Type User
```
Every recoverable deleted user.

### Example 2
```powershell
Get-GkDeletedItem -Type Group -ExpiringInDays 5
```
Deleted groups with fewer than five days left to restore.

### Example 3
```powershell
Get-GkDeletedItem -Type User -AsReport | Export-Csv .\deleted-users.csv -NoTypeInformation
```

## PARAMETERS

### -Type
The directory object type to list. Required — Graph has no "all deleted objects" endpoint.

```yaml
Type: String
Required: true
Position: 1
Default value: None
Accept pipeline input: false
```

### -DeletedWithinDays
Only return objects deleted within this many days.

```yaml
Type: Int32
Required: false
Position: 2
Default value: 0
Accept pipeline input: false
```

### -ExpiringInDays
Only return objects whose restore window closes within this many days. Use it to catch
anything about to be purged.

```yaml
Type: Int32
Required: false
Position: 3
Default value: 0
Accept pipeline input: false
```

### -First
Return at most this many objects.

```yaml
Type: Int32
Required: false
Position: 4
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
### PSGraphKit.DeletedItem
