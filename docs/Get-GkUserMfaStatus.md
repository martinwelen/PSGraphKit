# Get-GkUserMfaStatus

## SYNOPSIS
Report per-user authentication-method registration and MFA capability from the
authentication methods registration report.

## SYNTAX
```
Get-GkUserMfaStatus [-NotMfaCapableOnly] [-AdminsOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /reports/authenticationMethods/userRegistrationDetails, which returns a
ready-made per-user view of registered methods and capability flags across the tenant in
a single paged call — preferred over enumerating /users/{id}/authentication/methods per user.

Capability distinction (per Microsoft Graph):
  * IsMfaCapable    = registered a strong method that is ALLOWED by the auth methods policy.
  * IsMfaRegistered = registered a strong method (not necessarily policy-allowed).
The data has some latency; LastUpdated (lastUpdatedDateTime) reflects when it was refreshed.

Requires the AuditLog.Read.All scope (this endpoint does not accept Reports.Read.All).

## EXAMPLES

### Example 1
```powershell
Get-GkUserMfaStatus -NotMfaCapableOnly | Sort-Object UserPrincipalName
```
Every user who cannot perform MFA — the gap list.

### Example 2
```powershell
Get-GkUserMfaStatus -AdminsOnly | Where-Object { -not $_.IsMfaCapable }
```
Admins without MFA capability — a priority remediation set.

### Example 3
```powershell
Get-GkUserMfaStatus -AsReport | Export-Csv .\mfa-status.csv -NoTypeInformation
```

## PARAMETERS

### -NotMfaCapableOnly
Return only users who are not MFA-capable (server-side filter isMfaCapable eq false).

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AdminsOnly
Return only users flagged as admins (server-side filter isAdmin eq true).

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AsReport
Flatten MethodsRegistered to a single '; '-joined string and add ReportGeneratedUtc.

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
### PSGraphKit.UserMfaStatus
