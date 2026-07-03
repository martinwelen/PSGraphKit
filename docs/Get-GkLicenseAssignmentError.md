# Get-GkLicenseAssignmentError

## SYNOPSIS
Report users whose license assignments are in an error state.

## SYNTAX
```
Get-GkLicenseAssignmentError [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /users?$select=licenseAssignmentStates and emits one row per (user, failing SKU)
where the state is Error or ActiveWithError — for example count/dependency violations or a
usage-location problem. Group-based licensing failures are identified by AssignedByGroup.
SKU GUIDs are resolved to part numbers via /subscribedSkus.

Requires User.Read.All (and Organization.Read.All / Directory.Read.All to resolve SKU names).

## EXAMPLES

### Example 1
```powershell
Get-GkLicenseAssignmentError
```
All users with a failing license assignment, one row per erroring SKU.

### Example 2
```powershell
Get-GkLicenseAssignmentError | Where-Object AssignedByGroup
```
Failures coming from group-based licensing (fix at the group, not the user).

### Example 3
```powershell
Get-GkLicenseAssignmentError -AsReport | Export-Csv .\license-errors.csv -NoTypeInformation
```

## PARAMETERS

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
### PSGraphKit.LicenseAssignmentError
