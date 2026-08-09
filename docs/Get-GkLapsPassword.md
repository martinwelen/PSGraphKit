# Get-GkLapsPassword

## SYNOPSIS
Retrieve the Windows LAPS local administrator password for a device.

## SYNTAX
```
Get-GkLapsPassword [[-DeviceId] <string[]>] [-IncludePrevious] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /directory/deviceLocalCredentials/{deviceId}?$select=credentials, which returns
the Windows LAPS-managed local administrator account and its password, plus any previous
credentials still within the backup window.

Without -DeviceId the cmdlet instead lists which devices have LAPS credentials at all —
useful for confirming coverage. Graph enforces the split, and so do the scopes: the list
endpoint documents DeviceLocalCredential.ReadBasic.All and deliberately excludes passwords,
while retrieving one requires DeviceLocalCredential.Read.All. Only the scope for the mode
you are using is validated.

The password is returned as plain text on the result but is NOT shown by the default view,
so it does not splash across the screen or into a transcript. Capture it deliberately with
Select-Object Password. Reading a LAPS password is an audited, privileged action, and the
password should be rotated afterwards.

## EXAMPLES

### Example 1
```powershell
Get-GkLapsPassword -DeviceId $deviceId | Select-Object DeviceName, AccountName, Password
```
Retrieve the current local administrator password for one device.

### Example 2
```powershell
Get-GkLapsPassword
```
List the devices that have LAPS credentials, without reading any password.

### Example 3
```powershell
Get-GkDeviceInventory -StaleOnly | Get-GkLapsPassword -IncludePrevious
```

## PARAMETERS

### -DeviceId
One or more device IDs (the Entra deviceId, not the object id). Accepts pipeline input by
the DeviceId property, so Get-GkDeviceInventory output can be piped in. Omit to list
devices that have credentials, without retrieving any password.

```yaml
Type: String[]
Required: false
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -IncludePrevious
Also return credentials older than the current one, where the backup window still holds
them. Off by default: the current password is almost always what you want.

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
### PSGraphKit.LapsCredential
