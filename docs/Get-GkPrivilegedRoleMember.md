# Get-GkPrivilegedRoleMember

## SYNOPSIS
Report members of highly privileged directory roles, flagging permanent (non-PIM)
assignments.

## SYNTAX
```
Get-GkPrivilegedRoleMember [-PermanentOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Builds on Get-GkAdminRoleAssignment and narrows the result to a curated set of highly
privileged roles (Global Administrator, Privileged Role Administrator, Security
Administrator, Application Administrator, ...). Each row is flagged IsPermanent when it is a
directly assigned (Active) role rather than a PIM eligible/time-bound assignment — the
standing-privilege risk assessors look for.

Requires the same scope as Get-GkAdminRoleAssignment (RoleManagement.Read.All). PIM data
needs Microsoft Entra ID P2.

## EXAMPLES

### Example 1
```powershell
Get-GkPrivilegedRoleMember | Sort-Object RoleName
```
Everyone holding a highly privileged role, active and PIM.

### Example 2
```powershell
Get-GkPrivilegedRoleMember -PermanentOnly | Where-Object RoleName -eq 'Global Administrator'
```
Standing (non-PIM) Global Administrators — a key finding.

### Example 3
```powershell
Get-GkPrivilegedRoleMember -AsReport | Export-Csv .\privileged-roles.csv -NoTypeInformation
```

## PARAMETERS

### -PermanentOnly
Return only permanent (directly assigned, non-PIM) privileged assignments.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
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
### PSGraphKit.PrivilegedRoleMember
