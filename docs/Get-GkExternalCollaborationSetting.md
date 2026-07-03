# Get-GkExternalCollaborationSetting

## SYNOPSIS
Report the tenant's external-collaboration and default-user-permission settings.

## SYNTAX
```
Get-GkExternalCollaborationSetting [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /policies/authorizationPolicy and returns a single object summarizing who can
invite guests (allowInvitesFrom), the permission level guests get (guestUserRoleId mapped to
a friendly name), and the default permissions granted to member users (create apps, create
security groups, read other users, ...). These are common assessment findings.

Requires the Policy.Read.All scope.

## EXAMPLES

### Example 1
```powershell
Get-GkExternalCollaborationSetting
```
The tenant's guest-invite and default-user-permission posture.

### Example 2
```powershell
Get-GkExternalCollaborationSetting | Select-Object AllowInvitesFrom, GuestUserRole, DefaultUserCanCreateApps
```
The high-risk knobs.

### Example 3
```powershell
Get-GkExternalCollaborationSetting -AsReport | Export-Csv .\external-collab.csv -NoTypeInformation
```

## PARAMETERS

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
### PSGraphKit.ExternalCollaborationSetting
