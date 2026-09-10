function Get-GkGroupReport {
    <#
    .SYNOPSIS
        Report groups with their type (Microsoft 365 / security / distribution / dynamic),
        membership count, owners, and an ownerless flag.

    .DESCRIPTION
        Reads GET /groups and classifies each group from groupTypes/securityEnabled/mailEnabled.
        For each group it also fetches the membership count (GET /groups/{id}/members/$count, which
        requires the ConsistencyLevel: eventual header) and reads the owners (expanded on the group
        list via $expand=owners, one round-trip rather than a call per group), flagging ownerless groups.

        Caveat on ownerless detection: owners are not returned by Graph for groups created in
        Exchange, distribution groups, or on-premises-synced groups, so IsOwnerless can be a false
        positive for those. The GroupType column lets you account for that.

        Membership counting is one call per group; use -SkipMemberCount to omit it on large tenants.

    .PARAMETER GroupType
        Client-side filter: All (default), Microsoft365, Security, MailEnabledSecurity, or Distribution.

    .PARAMETER OwnerlessOnly
        Return only groups with no owners (see the ownerless caveat above).

    .PARAMETER SkipMemberCount
        Do not fetch per-group membership counts (MemberCount will be $null).

    .PARAMETER AsReport
        Flatten Owners to a '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkGroupReport -OwnerlessOnly | Where-Object GroupType -eq 'Microsoft365'

        Ownerless Microsoft 365 groups — a governance cleanup list.

    .EXAMPLE
        Get-GkGroupReport | Sort-Object MemberCount -Descending | Select-Object -First 20

        The 20 largest groups by membership.

    .EXAMPLE
        Get-GkGroupReport -SkipMemberCount -AsReport | Export-Csv .\groups.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.GroupReport
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.GroupReport')]
    param(
        [ValidateSet('All', 'Microsoft365', 'Security', 'MailEnabledSecurity', 'Distribution')]
        [string] $GroupType = 'All',

        [switch] $OwnerlessOnly,

        [switch] $SkipMemberCount,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkGroupReport' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $select = 'id,displayName,mail,groupTypes,securityEnabled,mailEnabled,membershipRule,membershipRuleProcessingState,visibility'
        # Expand owners on the list query — one round-trip for every group's owners instead of a
        # per-group GET /groups/{id}/owners (an N+1 that dominated runtime on large tenants). Graph
        # caps an expanded collection at ~20 items, so OwnerCount can under-report for groups with
        # >20 owners; IsOwnerless (zero owners) is unaffected.
        $groups = Invoke-GkGraphRequest -Uri "/groups?`$select=$select&`$expand=owners(`$select=id,displayName)&`$top=999" -CallerFunction 'Get-GkGroupReport'
        $memberCountFailures = 0

        foreach ($g in $groups) {
            $id         = [string](Get-GkDictValue $g 'id')
            $groupTypes = @(Get-GkDictValue $g 'groupTypes')
            $secEnabled = [bool](Get-GkDictValue $g 'securityEnabled')
            $mailEnab   = [bool](Get-GkDictValue $g 'mailEnabled')
            $isDynamic  = ($groupTypes -contains 'DynamicMembership')

            $type =
                if ($groupTypes -contains 'Unified')          { 'Microsoft365' }
                elseif ($secEnabled -and $mailEnab)           { 'MailEnabledSecurity' }
                elseif ($secEnabled -and -not $mailEnab)      { 'Security' }
                elseif ($mailEnab -and -not $secEnabled)      { 'Distribution' }
                else                                          { 'Unknown' }

            if ($GroupType -ne 'All' -and $type -ne $GroupType) { continue }

            # Members count (one call per group unless skipped).
            $memberCount = $null
            if (-not $SkipMemberCount -and $id) {
                try {
                    # NOTE: /members/$count returns text/plain, which breaks -OutputType Hashtable.
                    # Read @odata.count from a $count=true collection query (JSON) instead; $top=1
                    # keeps the payload tiny. Requires the ConsistencyLevel: eventual header.
                    $countResp = Invoke-GkGraphRequest -Raw -CallerFunction 'Get-GkGroupReport' `
                        -Uri "/groups/$id/members?`$count=true&`$top=1" -Headers @{ ConsistencyLevel = 'eventual' }
                    $memberCount = [int](Get-GkDictValue $countResp '@odata.count')
                }
                catch {
                    $memberCountFailures++
                    Write-Verbose "PSGraphKit: member count unavailable for group $id : $($_.Exception.Message)"
                }
            }

            # Owners (expanded on the list query above). Empty for group types Graph does not return
            # owners for — Exchange/distribution/on-prem-synced — which is the ownerless caveat noted
            # in the help, not a lookup failure.
            $owners = @(Get-GkDictValue $g 'owners')
            $ownerNames = @($owners | ForEach-Object { [string](Get-GkDictValue $_ 'displayName') } | Where-Object { $_ })

            if ($OwnerlessOnly -and $ownerNames.Count -gt 0) { continue }

            $obj = [ordered]@{
                PSTypeName     = 'PSGraphKit.GroupReport'
                DisplayName    = [string](Get-GkDictValue $g 'displayName')
                GroupType      = $type
                IsDynamic      = $isDynamic
                MemberCount    = $memberCount
                Owners         = if ($AsReport) { $ownerNames -join '; ' } else { , $ownerNames }
                OwnerCount     = $ownerNames.Count
                IsOwnerless    = ($ownerNames.Count -eq 0)
                Mail           = [string](Get-GkDictValue $g 'mail')
                Visibility     = [string](Get-GkDictValue $g 'visibility')
                MembershipRule = [string](Get-GkDictValue $g 'membershipRule')
                Id             = $id
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }

        if ($memberCountFailures -gt 0) {
            Write-Warning "Membership count could not be read for $memberCountFailures group(s) — MemberCount is null for those. Needs GroupMember.Read.All (or Group.Read.All) and the ConsistencyLevel: eventual header."
        }
    }
}
