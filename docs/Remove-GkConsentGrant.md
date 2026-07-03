# Remove-GkConsentGrant

## SYNOPSIS
Revoke a delegated OAuth2 permission grant (consent).

## SYNTAX
```
Remove-GkConsentGrant [-GrantId] <string[]> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Deletes an oauth2PermissionGrant (DELETE /oauth2PermissionGrants/{id}), revoking a delegated
permission consent — for example an over-privileged tenant-wide (AllPrincipals) grant surfaced
by Get-GkServicePrincipalReport -IncludeConsentGrants.

State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts grant IDs from the
pipeline and yields a PSGraphKit.ConsentGrantRemovalResult per grant; failures warn and continue.
Requires DelegatedPermissionGrant.ReadWrite.All.

Grant IDs come from GET /oauth2PermissionGrants (e.g. via Invoke-MgGraphRequest) — this cmdlet
performs the revoke once you have the id.

## EXAMPLES

### Example 1
```powershell
Remove-GkConsentGrant -GrantId $grantId -WhatIf
```
Preview revoking one consent grant.

### Example 2
```powershell
$grants = (Invoke-MgGraphRequest GET 'https://graph.microsoft.com/v1.0/oauth2PermissionGrants' -OutputType PSObject).value |
    Where-Object consentType -eq 'AllPrincipals'
$grants.id | Remove-GkConsentGrant -Confirm:$false
```
Revoke every tenant-wide delegated consent.

### Example 3
```powershell
Remove-GkConsentGrant -GrantId $id -Confirm:$false | Format-List GrantId, Outcome, Error
```

## PARAMETERS

### -GrantId
One or more oauth2PermissionGrant IDs to delete. Accepts pipeline input (incl. by the Id property).

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: true (ByValue, ByPropertyName)
```

### CommonParameters
This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, -WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. For more information, see about_CommonParameters.

## INPUTS
### None

## OUTPUTS
### PSGraphKit.ConsentGrantRemovalResult
