# Get-GkTenantInfo

## SYNOPSIS
Report high-level tenant information: name, type, directory size, sync status, contacts.

## SYNTAX
```
Get-GkTenantInfo [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /organization and returns a single object summarizing the tenant — useful as the
header of an assessment. Requires the Organization.Read.All scope (with only User.Read most
fields return null).

## EXAMPLES

### Example 1
```powershell
Get-GkTenantInfo
```
The tenant overview.

### Example 2
```powershell
Get-GkTenantInfo | Select-Object DisplayName, TenantId, OnPremisesSyncEnabled, DirectoryUsersUsed
```

### Example 3
```powershell
Get-GkTenantInfo -AsReport | Export-Csv .\tenant-info.csv -NoTypeInformation
```

## PARAMETERS

### -AsReport
Flatten TechnicalNotificationMails to a '; '-joined string and add ReportGeneratedUtc.

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
### PSGraphKit.TenantInfo
