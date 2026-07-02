function Get-GkGroupReport {
    <#
    .SYNOPSIS
        Report groups with their type (Microsoft 365 / security / distribution / dynamic),
        membership count, owners, and an ownerless flag.

    .DESCRIPTION
        Reads GET /groups and classifies each group from groupTypes/securityEnabled/mailEnabled.
        For each group it also fetches the membership count (GET /groups/{id}/members/$count, which
        requires the ConsistencyLevel: eventual header) and the owners (GET /groups/{id}/owners),
        flagging ownerless groups.

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
        Test-GkConnection -FunctionName 'Get-GkGroupReport' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $select = 'id,displayName,mail,groupTypes,securityEnabled,mailEnabled,membershipRule,membershipRuleProcessingState,visibility'
        $groups = Invoke-GkGraphRequest -Uri "/groups?`$select=$select&`$top=999" -CallerFunction 'Get-GkGroupReport'

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
                    $memberCount = [int](Invoke-GkGraphRequest -Raw -CallerFunction 'Get-GkGroupReport' `
                        -Uri "/groups/$id/members/`$count" -Headers @{ ConsistencyLevel = 'eventual' })
                }
                catch {
                    Write-Verbose "PSGraphKit: member count unavailable for group $id : $($_.Exception.Message)"
                }
            }

            # Owners.
            $ownerNames = @()
            if ($id) {
                try {
                    $owners = Invoke-GkGraphRequest -CallerFunction 'Get-GkGroupReport' -Uri "/groups/$id/owners?`$select=id,displayName"
                    $ownerNames = @($owners | ForEach-Object { [string](Get-GkDictValue $_ 'displayName') } | Where-Object { $_ })
                }
                catch {
                    Write-Verbose "PSGraphKit: owners unavailable for group $id : $($_.Exception.Message)"
                }
            }

            if ($OwnerlessOnly -and $ownerNames.Count -gt 0) { continue }

            $obj = [ordered]@{
                PSTypeName     = 'PSGraphKit.GroupReport'
                DisplayName    = [string](Get-GkDictValue $g 'displayName')
                GroupType      = $type
                IsDynamic      = $isDynamic
                MemberCount    = $memberCount
                Owners         = if ($AsReport) { $ownerNames -join '; ' } else { $ownerNames }
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
    }
}
