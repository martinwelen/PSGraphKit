function Get-GkServicePrincipalReport {
    <#
    .SYNOPSIS
        Report service principals (enterprise apps) with type, state, and optionally their
        tenant-wide OAuth2 consent grants.

    .DESCRIPTION
        Lists GET /servicePrincipals with the properties that matter for an app-security review:
        type, whether the app is enabled, whether app-role assignment is required, and tags. With
        -IncludeConsentGrants it also pulls GET /oauth2PermissionGrants (one tenant-wide call) and
        annotates each service principal with the number of delegated grants and whether any is
        consented for ALL users (consentType=AllPrincipals) — the over-privilege signal to flag.

        Requires Application.Read.All (and Directory.Read.All for the consent grants).

    .PARAMETER IncludeConsentGrants
        Annotate each service principal with DelegatedGrantCount and HasTenantWideConsent from
        /oauth2PermissionGrants.

    .PARAMETER Type
        Filter by servicePrincipalType (e.g. Application, ManagedIdentity, Legacy). Default all.

    .PARAMETER AsReport
        Flatten Tags to a '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkServicePrincipalReport -IncludeConsentGrants | Where-Object HasTenantWideConsent

        Enterprise apps with a tenant-wide (all-users) delegated consent.

    .EXAMPLE
        Get-GkServicePrincipalReport -Type ManagedIdentity

        List managed identity service principals.

    .EXAMPLE
        Get-GkServicePrincipalReport -AsReport | Export-Csv .\service-principals.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.ServicePrincipal
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.ServicePrincipal')]
    param(
        [switch] $IncludeConsentGrants,
        [string] $Type,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkServicePrincipalReport' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        # Build a clientId -> grants map once, if requested.
        $grantsByClient = @{}
        if ($IncludeConsentGrants) {
            foreach ($g in (Invoke-GkGraphRequest -Uri '/oauth2PermissionGrants' -CallerFunction 'Get-GkServicePrincipalReport')) {
                $client = [string](Get-GkDictValue $g 'clientId')
                if (-not $client) { continue }
                if (-not $grantsByClient.ContainsKey($client)) { $grantsByClient[$client] = [System.Collections.Generic.List[object]]::new() }
                $grantsByClient[$client].Add($g)
            }
        }

        $select = 'id,appId,displayName,accountEnabled,servicePrincipalType,appRoleAssignmentRequired,tags,signInAudience'
        # servicePrincipalType filters server-side, so -Type doesn't page the whole servicePrincipals
        # collection just to discard the non-matching ones.
        $spFilter = if ($Type) { "&`$filter=servicePrincipalType eq '$Type'" } else { '' }
        $sps = Invoke-GkGraphRequest -Uri "/servicePrincipals?`$select=$select$spFilter&`$top=999" -CallerFunction 'Get-GkServicePrincipalReport'

        foreach ($sp in $sps) {
            $spType = [string](Get-GkDictValue $sp 'servicePrincipalType')
            if ($Type -and $spType -ne $Type) { continue }

            $tags = @(Get-GkDictValue $sp 'tags')
            $id = [string](Get-GkDictValue $sp 'id')

            $obj = [ordered]@{
                PSTypeName                = 'PSGraphKit.ServicePrincipal'
                DisplayName               = [string](Get-GkDictValue $sp 'displayName')
                AppId                     = [string](Get-GkDictValue $sp 'appId')
                ServicePrincipalType      = $spType
                AccountEnabled            = [bool](Get-GkDictValue $sp 'accountEnabled')
                AppRoleAssignmentRequired = [bool](Get-GkDictValue $sp 'appRoleAssignmentRequired')
                SignInAudience            = [string](Get-GkDictValue $sp 'signInAudience')
                Tags                      = if ($AsReport) { $tags -join '; ' } else { , $tags }
                Id                        = $id
            }

            if ($IncludeConsentGrants) {
                $grants = @()
                if ($grantsByClient.ContainsKey($id)) { $grants = @($grantsByClient[$id]) }
                $obj['DelegatedGrantCount'] = $grants.Count
                $obj['HasTenantWideConsent'] = [bool](@($grants | Where-Object { [string](Get-GkDictValue $_ 'consentType') -eq 'AllPrincipals' }).Count)
            }

            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
