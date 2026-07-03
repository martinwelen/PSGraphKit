# Get-GkConsentRequest

## SYNOPSIS
Report pending admin-consent requests (apps waiting for an administrator to grant
permissions).

## SYNTAX
```
Get-GkConsentRequest [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /identityGovernance/appConsent/appConsentRequests — apps for which users have
requested admin consent. Requires the admin-consent workflow to be enabled in the tenant.

Requires the ConsentRequest.Read.All scope. Unavailable data warns and returns nothing.

## EXAMPLES

### Example 1
```powershell
Get-GkConsentRequest
```
Apps awaiting admin consent, with the number of pending permission scopes.

### Example 2
```powershell
Get-GkConsentRequest | Where-Object PendingScopeCount -gt 0 | Sort-Object AppDisplayName
```

### Example 3
```powershell
Get-GkConsentRequest -AsReport | Export-Csv .\consent-requests.csv -NoTypeInformation
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
### PSGraphKit.ConsentRequest
