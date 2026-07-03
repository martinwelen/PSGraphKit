# Get-GkAuthMethodPolicy

## SYNOPSIS
Report the tenant authentication-methods policy: which methods are enabled or disabled.

## SYNTAX
```
Get-GkAuthMethodPolicy [-EnabledOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /policies/authenticationMethodsPolicy and emits one row per authentication method
configuration (fido2, microsoftAuthenticator, sms, temporaryAccessPass, softwareOath, email,
voice, x509Certificate, ...) with its state. Useful for confirming which methods a tenant
permits.

Requires Policy.Read.AuthenticationMethod (or Policy.Read.All).

## EXAMPLES

### Example 1
```powershell
Get-GkAuthMethodPolicy | Sort-Object State, Method
```
All methods with their enabled/disabled state.

### Example 2
```powershell
Get-GkAuthMethodPolicy -EnabledOnly
```
Only the methods currently enabled in the tenant.

### Example 3
```powershell
Get-GkAuthMethodPolicy -AsReport | Export-Csv .\auth-methods.csv -NoTypeInformation
```

## PARAMETERS

### -EnabledOnly
Return only methods whose state is 'enabled'.

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
### PSGraphKit.AuthMethodState
