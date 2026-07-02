# Get-GkDeviceInventory

## SYNOPSIS
Inventory Entra-registered/joined devices with OS, join type, last activity, and a stale flag.

## SYNTAX
```
Get-GkDeviceInventory [[-StaleDays] <int>] [[-JoinType] <string>] [-StaleOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /devices and reports each device's operating system, join type, compliance/management
state, and inactivity derived from approximateLastSignInDateTime. Devices with no recorded
activity are treated as stale.

Join type is mapped from trustType (per Microsoft Graph):
  * AzureAd   -> AzureADJoined   (cloud-only Entra joined)
  * ServerAd  -> HybridJoined    (on-premises AD domain / hybrid joined)  [there is no "Hybrid" literal]
  * Workplace -> Registered      (personal / BYO registered)

Note: approximateLastSignInDateTime is APPROXIMATE — Entra updates it periodically, not in
real time — so treat the stale threshold as indicative, not exact.

## EXAMPLES

### Example 1
```powershell
Get-GkDeviceInventory -StaleOnly -StaleDays 180 | Sort-Object InactiveDays -Descending
```
Devices with no activity for 180+ days, most inactive first.

### Example 2
```powershell
Get-GkDeviceInventory -JoinType Registered | Where-Object { -not $_.IsCompliant }
```
Personal (registered) devices that are not compliant.

### Example 3
```powershell
Get-GkDeviceInventory -AsReport | Export-Csv .\devices.csv -NoTypeInformation
```

## PARAMETERS

### -StaleDays
Inactivity threshold in days (default 90). A device is stale when its last activity is at
least this many days ago, or when it has no recorded activity.

```yaml
Type: Int32
Required: false
Position: 1
Default value: 90
Accept pipeline input: false
```

### -StaleOnly
Return only stale devices.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -JoinType
Filter by join type: All (default), AzureADJoined, HybridJoined, or Registered.

```yaml
Type: String
Required: false
Position: 2
Default value: All
Accept pipeline input: false
```

### -AsReport
Add a ReportGeneratedUtc column for clean export.

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
### PSGraphKit.Device
