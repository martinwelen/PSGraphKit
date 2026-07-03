# Remove-GkUserLicense

## SYNOPSIS
Remove one or more license SKUs from users, reclaiming the seats.

## SYNTAX
```
Remove-GkUserLicense [-UserId] <string[]> [-SkuId] <string[]> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Calls POST /users/{id}/assignLicense with the SKU(s) in removeLicenses, releasing those
licenses from the user. Typically used to reclaim licenses from disabled or stale accounts.

State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts users from the
pipeline and yields a PSGraphKit.LicenseRemoveResult per user; a failure warns and continues.

SKU GUIDs come from Get-GkLicenseOverview (the SkuId column). Note: a license assigned via
group-based licensing cannot be removed per user — that returns a Graph error (reported as a
Failed result); change the group assignment instead.

Requires LicenseAssignment.ReadWrite.All (or Directory.ReadWrite.All / User.ReadWrite.All)
plus a supporting Entra role (e.g. License Administrator or User Administrator).

## EXAMPLES

### Example 1
```powershell
Remove-GkUserLicense -UserId ada@contoso.com -SkuId 6fd2c87f-b296-42f0-b197-1e91e994b900
```
Remove one SKU from one user (prompts for confirmation).

### Example 2
```powershell
$e3 = (Get-GkLicenseOverview | Where-Object SkuPartNumber -eq 'ENTERPRISEPACK').SkuId
Get-GkStaleUser -InactiveDays 365 | Remove-GkUserLicense -SkuId $e3 -WhatIf
```
Preview reclaiming Office 365 E3 from users stale 365+ days.

### Example 3
```powershell
'ada@contoso.com','bob@contoso.com' | Remove-GkUserLicense -SkuId $skuId -Confirm:$false |
    Where-Object Outcome -eq 'Failed'
```
Remove a SKU from several users without prompting and inspect any failures.

## PARAMETERS

### -UserId
One or more user object IDs or userPrincipalNames. Accepts pipeline input (incl. by the
UserPrincipalName / Id property).

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### -SkuId
One or more SKU GUIDs to remove (from Get-GkLicenseOverview's SkuId).

```yaml
Type: String[]
Required: true
Position: 2
Default value: None
Accept pipeline input: false
```

### CommonParameters
This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, -WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. For more information, see about_CommonParameters.

## INPUTS
### None

## OUTPUTS
### PSGraphKit.LicenseRemoveResult
