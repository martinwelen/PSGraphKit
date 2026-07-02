function Get-GkCurrentUserRole {
    <#
    .SYNOPSIS
        Return the signed-in admin's *active* directory role display names (delegated sessions),
        cached for the session. Used to make 403 messages specific.
    .DESCRIPTION
        Reads GET /me/transitiveMemberOf/microsoft.graph.directoryRole (OData cast filters the
        mixed memberOf collection to directory roles). Self-read least scope is User.Read, which
        is almost always present, so this usually works even when the failing report call did not.

        Caveats reflected by callers: this shows ACTIVE roles only — a PIM-eligible-but-inactive
        role will not appear. App-only sessions have no user roles, so this returns $null for them.
        Any failure is swallowed and returns $null (best-effort enrichment, never fatal).
    .OUTPUTS
        [string[]] of role display names, or $null.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [switch] $Refresh
    )

    if (-not $Refresh -and $null -ne $script:GkCurrentUserRoleCache) {
        return $script:GkCurrentUserRoleCache
    }

    $ctx = Get-MgContext
    if (-not $ctx -or $ctx.AuthType -ne 'Delegated') {
        return $null
    }

    try {
        $roles = Invoke-GkGraphRequest -Uri '/me/transitiveMemberOf/microsoft.graph.directoryRole?$select=displayName,roleTemplateId' `
            -SuppressRoleEnrichment
        $names = @(
            $roles |
                ForEach-Object { if ($_ -is [System.Collections.IDictionary] -and $_.Contains('displayName')) { [string]$_['displayName'] } } |
                Where-Object { $_ } |
                Sort-Object -Unique
        )
        $script:GkCurrentUserRoleCache = $names
        return $names
    }
    catch {
        Write-Verbose "PSGraphKit: could not enumerate current user roles: $($_.Exception.Message)"
        return $null
    }
}
