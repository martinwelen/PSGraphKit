function Get-GkGroupMember {
    <#
    .SYNOPSIS
        List the members of a group, classified by object type.

    .DESCRIPTION
        Reads GET /groups/{id}/members and returns one row per member with its directory object
        type resolved (user, group, servicePrincipal, device, orgContact). This is the read
        companion to Add-GkGroupMember / Remove-GkGroupMember, and pairs with Get-GkGroupReport —
        which reports member *counts* — when you need the actual names.

        Members are direct members only; nested group membership is not expanded. Requires
        GroupMember.Read.All (or a broader group/directory read scope).

    .PARAMETER GroupId
        One or more group object IDs. Accepts pipeline input, including by the Id / GroupId
        property so Get-GkGroupReport output can be piped in.

    .PARAMETER MemberType
        Only return members of this directory object type. Defaults to All.

    .PARAMETER First
        Return at most this many members per group.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkGroupMember -GroupId $groupId

        List every member of one group.

    .EXAMPLE
        Get-GkGroupReport -OwnerlessOnly | Get-GkGroupMember -MemberType User

        List the users in every ownerless group.

    .EXAMPLE
        Get-GkGroupMember -GroupId $id -AsReport | Export-Csv .\members.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.GroupMember
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.GroupMember')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string[]] $GroupId,

        [ValidateSet('All', 'User', 'Group', 'ServicePrincipal', 'Device', 'OrgContact')]
        [string] $MemberType = 'All',

        [int] $First,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkGroupMember' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        foreach ($gid in $GroupId) {
            if ([string]::IsNullOrWhiteSpace($gid)) { continue }
            $enc = [uri]::EscapeDataString($gid)

            $params = @{
                Uri            = "/groups/$enc/members?`$select=id,displayName,userPrincipalName,accountEnabled,mail"
                CallerFunction = 'Get-GkGroupMember'
            }
            if ($PSBoundParameters.ContainsKey('First')) { $params['MaxResult'] = $First }

            try {
                $members = Invoke-GkGraphRequest @params
            }
            catch {
                Write-Warning "Could not read members of '$gid': $($_.Exception.Message)"
                continue
            }

            foreach ($m in $members) {
                # Graph returns the concrete type as @odata.type, e.g. '#microsoft.graph.user'.
                $odata = [string](Get-GkDictValue $m '@odata.type')
                $type = if ($odata) { ($odata -replace '^#microsoft\.graph\.', '') } else { 'unknown' }
                $type = if ($type) { $type.Substring(0, 1).ToUpper() + $type.Substring(1) } else { 'Unknown' }

                if ($MemberType -ne 'All' -and $type -ne $MemberType) { continue }

                $obj = [ordered]@{
                    PSTypeName        = 'PSGraphKit.GroupMember'
                    GroupId           = $gid
                    MemberType        = $type
                    DisplayName       = [string](Get-GkDictValue $m 'displayName')
                    UserPrincipalName = [string](Get-GkDictValue $m 'userPrincipalName')
                    Mail              = [string](Get-GkDictValue $m 'mail')
                    AccountEnabled    = Get-GkDictValue $m 'accountEnabled'
                    Id                = [string](Get-GkDictValue $m 'id')
                }
                if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
                [pscustomobject]$obj
            }
        }
    }
}
