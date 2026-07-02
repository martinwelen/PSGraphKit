# Get-GkLicenseOverview

## SYNOPSIS
Report subscribed license SKUs with enabled/assigned/available counts, and optionally the
number of disabled-but-licensed users per SKU.

## SYNTAX
```
Get-GkLicenseOverview [-IncludeDisabledLicensed] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /subscribedSkus and returns one row per SKU with the total enabled seats
(prepaidUnits.enabled), assigned seats (consumedUnits), computed available seats, and the
warning/suspended/lockedOut unit counts. A best-effort friendly product name is resolved
from the SKU part number (the raw SkuPartNumber is always included as the source of truth).

With -IncludeDisabledLicensed, each SKU is additionally cross-referenced against
GET /users?$filter=assignedLicenses/any(...) to count users who hold the SKU while disabled
(accountEnabled = false) — a common license-reclamation target. This adds one user query per
SKU, so it is opt-in.

## EXAMPLES

### Example 1
```powershell
Get-GkLicenseOverview | Sort-Object Available
```
All SKUs, scarcest availability first.

### Example 2
```powershell
Get-GkLicenseOverview -IncludeDisabledLicensed |
    Where-Object DisabledLicensedCount -gt 0 |
    Sort-Object DisabledLicensedCount -Descending
```
SKUs with the most licenses assigned to disabled accounts (reclamation candidates).

### Example 3
```powershell
Get-GkLicenseOverview -AsReport | Export-Csv .\licenses.csv -NoTypeInformation
```

## PARAMETERS

### -IncludeDisabledLicensed
For each SKU, count users assigned that SKU whose account is disabled. Adds a
DisabledLicensedCount column. Requires a scope that can read users (e.g. User.Read.All).

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
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
### PSGraphKit.LicenseOverview
