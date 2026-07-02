# Connect-GkGraph

## SYNOPSIS
Connect to Microsoft Graph for PSGraphKit — a thin wrapper over Connect-MgGraph that can
derive the required scopes from the cmdlets you intend to run.

## SYNTAX
```
Connect-GkGraph [[-Scopes] <string[]>] [[-ForCommand] <string[]>] [[-TenantId] <string>] [[-ClientId] <string>] [[-CertificateThumbprint] <string>] [[-Certificate] <X509Certificate2>] [-AllCommands] [-NoWelcome] [<CommonParameters>]
```

## DESCRIPTION
PSGraphKit is auth-agnostic and works with any Connect-MgGraph session, so this helper is
optional. Its value is scope derivation: instead of hand-assembling a -Scopes list, name the
cmdlets you plan to use (-ForCommand) or ask for everything (-AllCommands) and it computes the
least-privileged scope set from the module's scope map, then connects delegated.

For app-only (enterprise app) authentication, pass -ClientId, -TenantId and a certificate
(-CertificateThumbprint or -Certificate); scopes are consented on the app registration in
that model, so any -Scopes/-ForCommand input is ignored. After connecting, the current
session is returned as a PSGraphKit.ConnectionInfo object.

## EXAMPLES

### Example 1
```powershell
Connect-GkGraph -ForCommand Get-GkStaleUser, Get-GkGuestInventory
```
Connect delegated with exactly the scopes those two cmdlets need.

### Example 2
```powershell
Connect-GkGraph -AllCommands
```
Connect delegated with the full read-only scope set for every PSGraphKit cmdlet.

### Example 3
```powershell
Connect-GkGraph -ClientId $appId -TenantId contoso.onmicrosoft.com -CertificateThumbprint $thumb
```
Connect app-only (enterprise app) with a certificate.

## PARAMETERS

### -Scopes
Explicit delegated scopes to request (passed through to Connect-MgGraph).

```yaml
Type: String[]
Required: false
Position: 1
Default value: None
Accept pipeline input: false
```

### -ForCommand
One or more PSGraphKit cmdlet names; their required scopes are derived from the scope map and
unioned into the request. Combine with -Scopes to add extras.

```yaml
Type: String[]
Required: false
Position: 2
Default value: None
Accept pipeline input: false
```

### -AllCommands
Request the union of scopes for every PSGraphKit cmdlet (the full read-only footprint).

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -TenantId
Target tenant (GUID or domain). Optional for delegated, required for app-only.

```yaml
Type: String
Required: false
Position: 3
Default value: None
Accept pipeline input: false
```

### -ClientId
App (client) ID for app-only authentication.

```yaml
Type: String
Required: false
Position: 4
Default value: None
Accept pipeline input: false
```

### -CertificateThumbprint
Thumbprint of a certificate in the current user/machine store, for app-only authentication.

```yaml
Type: String
Required: false
Position: 5
Default value: None
Accept pipeline input: false
```

### -Certificate
An X509Certificate2 object, for app-only authentication.

```yaml
Type: X509Certificate2
Required: false
Position: 6
Default value: None
Accept pipeline input: false
```

### -NoWelcome
Suppress the Connect-MgGraph welcome banner.

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
### PSGraphKit.ConnectionInfo
