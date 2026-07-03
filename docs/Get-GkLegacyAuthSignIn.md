# Get-GkLegacyAuthSignIn

## SYNOPSIS
Report sign-ins that used legacy authentication clients — a prime attack vector.

## SYNTAX
```
Get-GkLegacyAuthSignIn [[-Days] <int>] [-SuccessfulOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /auditLogs/signIns over the last -Days and keeps only sign-ins whose client app is
a legacy protocol (Exchange ActiveSync, IMAP, POP, SMTP, MAPI, Other clients, ...). Legacy
auth cannot enforce MFA, so surfacing which users/apps still use it is a top hardening task.

Requires AuditLog.Read.All and a Microsoft Entra ID P1/P2 license. Unavailable data warns and
returns nothing.

## EXAMPLES

### Example 1
```powershell
Get-GkLegacyAuthSignIn -Days 7 | Group-Object UserPrincipalName | Sort-Object Count -Descending
```
Users still authenticating with legacy protocols in the last week.

### Example 2
```powershell
Get-GkLegacyAuthSignIn -SuccessfulOnly | Select-Object UserPrincipalName, ClientApp, IpAddress
```
Successful legacy-auth sign-ins to prioritize blocking.

### Example 3
```powershell
Get-GkLegacyAuthSignIn -AsReport | Export-Csv .\legacy-auth.csv -NoTypeInformation
```

## PARAMETERS

### -Days
Look-back window in days (default 7).

```yaml
Type: Int32
Required: false
Position: 1
Default value: 7
Accept pipeline input: false
```

### -SuccessfulOnly
Return only successful legacy-auth sign-ins (the ones that actually got in).

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
### PSGraphKit.SignIn
