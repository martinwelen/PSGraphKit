# Disable-GkStaleDevice

## SYNOPSIS
Disable (default) or delete stale Entra devices.

## SYNTAX
```
Disable-GkStaleDevice [-Id] <string[]> [-Delete] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
By default blocks the device (PATCH /devices/{id} accountEnabled=false). With -Delete it
deletes the device (DELETE /devices/{id}); deletion is a 30-day soft-delete. Typically fed
from Get-GkDeviceInventory -StaleOnly.

State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts devices from the
pipeline (by the Id property, so Get-GkDeviceInventory output pipes in) and yields a
PSGraphKit.DeviceDisableResult per device; failures warn and continue.

Delegated device writes use Directory.AccessAsUser.All (there is no delegated
Device.ReadWrite.All) and require a supporting Entra role — Cloud Device Administrator to
enable/disable, Intune Administrator to delete.

## EXAMPLES

### Example 1
```powershell
Get-GkDeviceInventory -StaleOnly -StaleDays 180 | Disable-GkStaleDevice -WhatIf
```
Preview disabling devices with no activity for 180+ days.

### Example 2
```powershell
Get-GkDeviceInventory -StaleOnly -StaleDays 365 | Disable-GkStaleDevice -Confirm:$false
```
Disable devices inactive 365+ days.

### Example 3
```powershell
Disable-GkStaleDevice -DeviceId 11111111-1111-1111-1111-111111111111 -Delete
```
Delete one device by object id (prompts for confirmation).

## PARAMETERS

### -Id
One or more device OBJECT IDs (the Id from Get-GkDeviceInventory, not the deviceId GUID).
Accepts pipeline input by the Id property; -DeviceId remains a back-compat alias. Binding to
Id — not DeviceId — is deliberate: Get-GkDeviceInventory emits BOTH properties, /devices/{id}
needs the object id, and PowerShell binds a parameter's formal name over its alias.

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -Delete
Delete the device (soft-delete) instead of only disabling it.

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
### PSGraphKit.DeviceDisableResult
