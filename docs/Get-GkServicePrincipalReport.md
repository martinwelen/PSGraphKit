# Get-GkServicePrincipalReport

## SYNOPSIS
Report service principals (enterprise apps) with type, state, and optionally their
tenant-wide OAuth2 consent grants.

## SYNTAX
```
Get-GkServicePrincipalReport [[-Type] <string>] [-IncludeConsentGrants] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Lists GET /servicePrincipals with the properties that matter for an app-security review:
type, whether the app is enabled, whether app-role assignment is required, and tags. With
-IncludeConsentGrants it also pulls GET /oauth2PermissionGrants (one tenant-wide call) and
annotates each service principal with the number of delegated grants and whether any is
consented for ALL users (consentType=AllPrincipals) — the over-privilege signal to flag.

Requires Application.Read.All (and Directory.Read.All for the consent grants).

## EXAMPLES

### Example 1
```powershell
Get-GkServicePrincipalReport -IncludeConsentGrants | Where-Object HasTenantWideConsent
```
Enterprise apps with a tenant-wide (all-users) delegated consent.

### Example 2
```powershell
Get-GkServicePrincipalReport -Type ManagedIdentity
```
List managed identity service principals.

### Example 3
```powershell
Get-GkServicePrincipalReport -AsReport | Export-Csv .\service-principals.csv -NoTypeInformation
```

## PARAMETERS

### -IncludeConsentGrants
Annotate each service principal with DelegatedGrantCount and HasTenantWideConsent from
/oauth2PermissionGrants.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -Type
Filter by servicePrincipalType (e.g. Application, ManagedIdentity, Legacy). Default all.

```yaml
Type: String
Required: false
Position: 1
Default value: None
Accept pipeline input: false
```

### -AsReport
Flatten Tags to a '; '-joined string and add ReportGeneratedUtc.

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
### PSGraphKit.ServicePrincipal
