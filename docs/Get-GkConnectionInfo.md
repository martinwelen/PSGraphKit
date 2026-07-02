# Get-GkConnectionInfo

## SYNOPSIS
Show the current Microsoft Graph session: identity, auth type, granted scopes, and
(for delegated sessions) the signed-in admin's active directory roles.

## SYNTAX
```
Get-GkConnectionInfo [-RefreshRoles] [<CommonParameters>]
```

## DESCRIPTION
A "whoami" for PSGraphKit. Run it at the start of an engagement to confirm you are
connected with enough privilege BEFORE generating reports, rather than discovering
gaps mid-run. Returns a single PSGraphKit.ConnectionInfo object.

ActiveRoles reflects ACTIVE role assignments only (delegated sessions). A role you are
PIM-eligible for but have not activated will not appear. App-only sessions have no user
roles, so ActiveRoles is empty and effective access is the granted application permissions.

## EXAMPLES

### Example 1
```powershell
Get-GkConnectionInfo
```
Shows the connected account, tenant, auth type, scopes, and active roles.

### Example 2
```powershell
(Get-GkConnectionInfo).Scopes
```
Returns just the granted scope strings — handy for scripting a pre-flight check.

### Example 3
```powershell
if (-not (Get-GkConnectionInfo).IsConnected) { Connect-MgGraph -Scopes User.Read.All,AuditLog.Read.All }
```
Connect only when there is no active session.

## PARAMETERS

### -RefreshRoles
Bypass the per-session role cache and re-query the signed-in admin's active roles.

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
