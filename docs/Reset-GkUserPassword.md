# Reset-GkUserPassword

## SYNOPSIS
Reset a user's password, optionally forcing a change at next sign-in.

## SYNTAX
```
Reset-GkUserPassword [-UserId] <string[]> [[-NewPassword] <securestring>] [-NoForceChange] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Calls PATCH /users/{id} with a passwordProfile. By default a strong random password is
generated and returned once on the result object, and the user must change it at next
sign-in — the safe default for a helpdesk reset.

The generated password is returned as plain text on the result but is NOT shown by the
default view, so it does not splash across the screen or into a transcript. Capture it
deliberately with Select-Object Password, the same way Reset-GkAppCredential surfaces a
new client secret.

State-changing: supports -WhatIf / -Confirm and prompts by default.

Requires User-PasswordProfile.ReadWrite.All — the narrow permission Graph documents for the
passwordProfile property — or a broader user write scope. The signed-in admin also needs a
role that outranks the target: User Administrator resets non-admins, and Privileged
Authentication Administrator is required to reset an administrator.

## EXAMPLES

### Example 1
```powershell
Reset-GkUserPassword -UserId ada@contoso.com | Select-Object UserId, Password
```
Reset with a generated password and capture it (it cannot be retrieved again).

### Example 2
```powershell
Reset-GkUserPassword -UserId ada@contoso.com -WhatIf
```
Preview the reset without changing anything.

### Example 3
```powershell
Get-GkRiskyUser -RiskLevel high | Reset-GkUserPassword -Confirm:$false |
    Where-Object Outcome -eq 'Failed'
```
Reset every high-risk user and inspect the failures.

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

### -NewPassword
Use this password instead of generating one. It must satisfy the tenant password policy.
Takes a SecureString, the PowerShell convention for a credential you already hold:
ConvertTo-SecureString 'value' -AsPlainText -Force.

```yaml
Type: SecureString
Required: false
Position: 2
Default value: None
Accept pipeline input: false
```

### -NoForceChange
Do not require the user to change the password at next sign-in. Off by default because a
helpdesk-set password that persists is a standing credential.

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
### PSGraphKit.PasswordResetResult
