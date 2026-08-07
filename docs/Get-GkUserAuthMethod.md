# Get-GkUserAuthMethod

## SYNOPSIS
List the authentication methods registered on a user's account.

## SYNTAX
```
Get-GkUserAuthMethod [-UserId] <string[]> [[-MethodType] <string>] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /users/{id}/authentication/methods and returns one row per registered method with
its type resolved (Microsoft Authenticator, FIDO2, phone, TAP, Windows Hello, password, ...).
Get-GkUserMfaStatus reports the tenant-wide registration *summary*; this is the per-user
detail behind it, for when you need to know exactly what an account can sign in with.

Reading another user's methods requires UserAuthenticationMethod.Read.All. The narrower
UserAuthenticationMethod.Read grants only the signed-in user's own methods, so it is not
accepted here.

No secret material is returned by Graph, but phone numbers and device names are: treat the
output as sensitive.

## EXAMPLES

### Example 1
```powershell
Get-GkUserAuthMethod -UserId ada@contoso.com
```
Every method registered on one account.

### Example 2
```powershell
Get-GkUserMfaStatus | Where-Object { -not $_.IsMfaCapable } | Get-GkUserAuthMethod
```
Inspect what the users who are not MFA-capable actually have registered.

### Example 3
```powershell
Get-GkUserAuthMethod -UserId ada@contoso.com -MethodType Fido2
```

## PARAMETERS

### -UserId
One or more user object IDs or userPrincipalNames. Accepts pipeline input, including by the
UserPrincipalName / Id property so report output can be piped in.

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -MethodType
Only return methods of this type (matched against the resolved MethodType column).

```yaml
Type: String
Required: false
Position: 2
Default value: None
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
### PSGraphKit.UserAuthMethod
