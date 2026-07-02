# Get-GkAppRegistrationReport

## SYNOPSIS
Report app registrations with credential (secret/certificate) expiry and high-privilege
API permissions.

## SYNTAX
```
Get-GkAppRegistrationReport [[-ExpiringInDays] <int>] [-ExpiringOnly] [-HighPrivilegeOnly] [-SkipPermissionResolution] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /applications and, per app, summarizes:
  * Credentials — passwordCredentials (secrets) and keyCredentials (certificates): counts,
    the earliest upcoming expiry, and how many are expired or expiring within a threshold.
  * Permissions — requiredResourceAccess resolved to human names by looking up each resource
    service principal's appRoles (application permissions, type Role) and oauth2PermissionScopes
    (delegated, type Scope). Application permissions matching a high-risk set (broad *.ReadWrite.All,
    RoleManagement.ReadWrite.Directory, Application.ReadWrite.All, full_access_as_app, ...) are
    flagged. Permission GUIDs are resolved live — never guessed — and cached per run.

Use -SkipPermissionResolution to skip the service-principal lookups (faster; permissions are
left as GUIDs and high-privilege detection is unavailable).

## EXAMPLES

### Example 1
```powershell
Get-GkAppRegistrationReport -ExpiringInDays 30 -ExpiringOnly | Sort-Object DaysUntilExpiry
```
Apps with a secret/cert expired or expiring within 30 days, soonest first.

### Example 2
```powershell
Get-GkAppRegistrationReport -HighPrivilegeOnly |
    Select-Object DisplayName, HighPrivilegePermissions
```
Apps granted high-privilege application permissions.

### Example 3
```powershell
Get-GkAppRegistrationReport -SkipPermissionResolution -AsReport |
    Export-Csv .\apps.csv -NoTypeInformation
```

## PARAMETERS

### -ExpiringInDays
Window in days for the ExpiringSoonCount / -ExpiringOnly filter (default 30).

```yaml
Type: Int32
Required: false
Position: 1
Default value: 30
Accept pipeline input: false
```

### -ExpiringOnly
Return only apps with a credential already expired or expiring within ExpiringInDays.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -HighPrivilegeOnly
Return only apps holding at least one flagged high-privilege application permission.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -SkipPermissionResolution
Do not resolve permission GUIDs to names (skips per-resource servicePrincipal lookups).

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AsReport
Flatten HighPrivilegePermissions to a '; '-joined string and add ReportGeneratedUtc.

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
### PSGraphKit.AppRegistration
