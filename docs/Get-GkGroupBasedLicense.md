# Get-GkGroupBasedLicense

## SYNOPSIS
Report groups that assign licenses, and whether their assignment has finished processing.

## SYNTAX
```
Get-GkGroupBasedLicense [[-Name] <string>] [[-First] <int>] [-NotProcessedOnly] [-ResolveSkuName] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /groups selecting assignedLicenses and licenseProcessingState, and returns only
the groups that actually carry a license assignment. Group-based licensing is invisible in
most reports until it breaks, and licenseProcessingState is the field that tells you a
change is still rolling out — or stuck.

Pairs with Get-GkLicenseAssignmentError, which reports the affected *users*; this reports
the group that assigned the licence to them. Requires Group.Read.All (or Directory.Read.All).

## EXAMPLES

### Example 1
```powershell
Get-GkGroupBasedLicense
```
Every group that assigns a licence.

### Example 2
```powershell
Get-GkGroupBasedLicense -NotProcessedOnly
```
Group licence assignments that have not finished applying.

### Example 3
```powershell
Get-GkGroupBasedLicense -AsReport | Export-Csv .\group-licensing.csv -NoTypeInformation
```

## PARAMETERS

### -Name
Only return groups whose display name contains this text (case-insensitive).

```yaml
Type: String
Required: false
Position: 1
Default value: None
Accept pipeline input: false
```

### -NotProcessedOnly
Only return groups whose licenseProcessingState is not ProcessingComplete — the ones still
rolling out, or stuck.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -ResolveSkuName
Resolve each skuId GUID to its SKU part number and friendly name. Costs one extra call to
/subscribedSkus and therefore needs a second scope (Organization.Read.All or
Directory.Read.All), which is only validated when you ask for it.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -First
Return at most this many groups.

```yaml
Type: Int32
Required: false
Position: 2
Default value: 0
Accept pipeline input: false
```

### -AsReport
Add a ReportGeneratedUtc column and flatten the SKU list to a string.

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
### PSGraphKit.GroupBasedLicense
