# Reset-GkAppCredential

## SYNOPSIS
Add or remove an app registration's client secret.

## SYNTAX
```
Reset-GkAppCredential -ApplicationId <string[]> [-DisplayName <string>] [-ValidMonths <int>] [-WhatIf] [-Confirm] [<CommonParameters>]

Reset-GkAppCredential -ApplicationId <string[]> -RemoveKeyId <string> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Manages application client secrets:
  * Add (default)   POST /applications/{id}/addPassword — returns the new secretText ONCE
    (it cannot be retrieved again, so it is surfaced on the result object). Use -DisplayName
    and -ValidMonths to control the credential.
  * Remove          POST /applications/{id}/removePassword -RemoveKeyId <keyId>.

Certificate rotation is intentionally not supported: addKey/removeKey require a
proof-of-possession JWT signed by an existing private key, which is outside this module's
scope. Manage certificates with a dedicated tool that holds the key material.

State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts applications from
the pipeline (by the Id property, i.e. the application OBJECT id from
Get-GkAppRegistrationReport) and yields a PSGraphKit.AppCredentialResult per application.
Requires Application.ReadWrite.All plus a supporting Entra role (e.g. Application Administrator).

## EXAMPLES

### Example 1
```powershell
Reset-GkAppCredential -ApplicationId $appObjectId -DisplayName 'rotated 2026' -Confirm:$false |
    Select-Object ApplicationId, KeyId, SecretText
```
Add a new client secret and capture the generated value (shown once).

### Example 2
```powershell
Reset-GkAppCredential -ApplicationId $appObjectId -RemoveKeyId $oldKeyId -WhatIf
```
Preview removing a specific secret.

### Example 3
```powershell
Get-GkAppRegistrationReport -ExpiringOnly | Reset-GkAppCredential -WhatIf
```
Preview adding a fresh secret to every app with an expiring credential.

## PARAMETERS

### -ApplicationId
One or more application OBJECT IDs (the Id from Get-GkAppRegistrationReport, not AppId).

```yaml
Type: String[]
Required: true
Position: named
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -DisplayName
Friendly name for the new secret (Add set). Default 'PSGraphKit secret'.

```yaml
Type: String
Required: false
Position: named
Default value: PSGraphKit secret
Accept pipeline input: false
```

### -ValidMonths
Lifetime of the new secret in months (Add set). Default 12.

```yaml
Type: Int32
Required: false
Position: named
Default value: 12
Accept pipeline input: false
```

### -RemoveKeyId
keyId of the secret to remove (Remove set).

```yaml
Type: String
Required: true
Position: named
Default value: None
Accept pipeline input: false
```

### CommonParameters
This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, -WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. For more information, see about_CommonParameters.

## INPUTS
### None

## OUTPUTS
### PSGraphKit.AppCredentialResult
