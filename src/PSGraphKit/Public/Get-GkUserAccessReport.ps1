function Get-GkUserAccessReport {
    <#
    .SYNOPSIS
        Report a single user's full access footprint: group memberships, directory roles,
        licenses, and application role assignments.

    .DESCRIPTION
        For each user, gathers:
          * Identity           GET /users/{id}
          * Groups & roles     GET /users/{id}/transitiveMemberOf  (classified by type)
          * App assignments    GET /users/{id}/appRoleAssignments
          * Licenses           GET /users/{id}/licenseDetails
        and returns one object per user with the collections plus counts.

        Because licenseDetails has no application permission, this cmdlet requires a DELEGATED
        session; Test-GkConnection blocks app-only sessions. Individual facets that fail (e.g. a
        denied sub-resource) warn and continue so the rest of the report still returns. A user id
        that cannot be resolved is skipped with a warning.

    .PARAMETER UserId
        One or more user object IDs or userPrincipalNames. Accepts pipeline input (including by the
        UserPrincipalName/Id property, so output of other cmdlets can be piped in).

    .PARAMETER AsReport
        Flatten the Groups/DirectoryRoles/Licenses/AppRoleAssignments collections to '; '-joined
        strings and add ReportGeneratedUtc for clean export.

    .EXAMPLE
        Get-GkUserAccessReport -UserId ada@contoso.com

        Full access footprint for one user.

    .EXAMPLE
        'ada@contoso.com','bob@contoso.com' | Get-GkUserAccessReport -AsReport |
            Export-Csv .\access.csv -NoTypeInformation

        Footprints for several users, flattened for export.

    .EXAMPLE
        Get-GkAdminRoleAssignment -AssignmentKind Active |
            Select-Object -ExpandProperty PrincipalId -Unique |
            Get-GkUserAccessReport

        Pipe the principals holding active roles into a full access report.

    .OUTPUTS
        PSGraphKit.UserAccessReport
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.UserAccessReport')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserPrincipalName', 'Id', 'PrincipalId')]
        [string[]] $UserId,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkUserAccessReport' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        foreach ($uid in $UserId) {
            if ([string]::IsNullOrWhiteSpace($uid)) { continue }

            # Percent-encode the id for the URL path segment. Object IDs (GUIDs) are unaffected,
            # but guest UPNs contain '#' (e.g. bob_x.com#EXT#@contoso.onmicrosoft.com) which a URL
            # otherwise treats as a fragment delimiter and truncates the request.
            $enc = [uri]::EscapeDataString($uid)

            try {
                $user = Invoke-GkGraphRequest -Raw `
                    -Uri "/users/$enc`?`$select=id,displayName,userPrincipalName,accountEnabled,userType" `
                    -CallerFunction 'Get-GkUserAccessReport'
            }
            catch {
                Write-Warning "Skipping '$uid': could not resolve user. $($_.Exception.Message)"
                continue
            }

            # Facet helper: return the collection, or warn+empty on failure.
            $facet = {
                param($relativeUri, $label)
                try { return @(Invoke-GkGraphRequest -Uri $relativeUri -CallerFunction 'Get-GkUserAccessReport') }
                catch {
                    Write-Warning "Could not read $label for '$uid': $($_.Exception.Message)"
                    return @()
                }
            }

            $memberOf = & $facet "/users/$enc/transitiveMemberOf?`$select=id,displayName,@odata.type" 'group/role memberships'
            $appRoles = & $facet "/users/$enc/appRoleAssignments" 'app role assignments'
            $licenses = & $facet "/users/$enc/licenseDetails" 'license details'

            $groups = @(); $roles = @()
            foreach ($m in $memberOf) {
                $type = [string](Get-GkDictValue $m '@odata.type')
                $name = [string](Get-GkDictValue $m 'displayName')
                if (-not $name) { continue }
                switch ($type) {
                    '#microsoft.graph.group'         { $groups += $name }
                    '#microsoft.graph.directoryRole' { $roles  += $name }
                    default { }  # administrativeUnit and others are intentionally not listed here
                }
            }

            $apps = @($appRoles | ForEach-Object { [string](Get-GkDictValue $_ 'resourceDisplayName') } | Where-Object { $_ })
            $skus = @($licenses | ForEach-Object { [string](Get-GkDictValue $_ 'skuPartNumber') } | Where-Object { $_ })

            $obj = [ordered]@{
                PSTypeName         = 'PSGraphKit.UserAccessReport'
                UserPrincipalName  = [string](Get-GkDictValue $user 'userPrincipalName')
                DisplayName        = [string](Get-GkDictValue $user 'displayName')
                AccountEnabled     = [bool](Get-GkDictValue $user 'accountEnabled')
                UserType           = [string](Get-GkDictValue $user 'userType')
                Groups             = if ($AsReport) { $groups -join '; ' } else { $groups }
                GroupCount         = $groups.Count
                DirectoryRoles     = if ($AsReport) { $roles -join '; ' } else { $roles }
                RoleCount          = $roles.Count
                Licenses           = if ($AsReport) { $skus -join '; ' } else { $skus }
                LicenseCount       = $skus.Count
                AppRoleAssignments = if ($AsReport) { $apps -join '; ' } else { $apps }
                AppCount           = $apps.Count
                Id                 = [string](Get-GkDictValue $user 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
