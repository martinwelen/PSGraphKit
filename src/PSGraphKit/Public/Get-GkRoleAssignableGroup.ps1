function Get-GkRoleAssignableGroup {
    <#
    .SYNOPSIS
        Report role-assignable ("privileged") groups and their owners, flagging ownerless ones.

    .DESCRIPTION
        Reads GET /groups filtered to isAssignableToRole eq true. These groups can be granted
        directory roles, so their owners and members are effectively privileged — a common
        assessment focus ("privileged unprotected groups"). Owners are resolved per group and
        ownerless groups are flagged.

        Requires Group.Read.All. Uses the ConsistencyLevel: eventual advanced-query header.

    .PARAMETER OwnerlessOnly
        Return only role-assignable groups that have no owners.

    .PARAMETER AsReport
        Flatten Owners to a '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkRoleAssignableGroup

        All role-assignable groups with owners and ownerless flag.

    .EXAMPLE
        Get-GkRoleAssignableGroup -OwnerlessOnly

        Privileged groups nobody owns — a governance gap.

    .EXAMPLE
        Get-GkRoleAssignableGroup -AsReport | Export-Csv .\role-assignable-groups.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.RoleAssignableGroup
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.RoleAssignableGroup')]
    param(
        [switch] $OwnerlessOnly,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkRoleAssignableGroup' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $select = 'id,displayName,groupTypes,securityEnabled,mailEnabled,visibility,isAssignableToRole'
        $groups = Invoke-GkGraphRequest -CallerFunction 'Get-GkRoleAssignableGroup' -Headers @{ ConsistencyLevel = 'eventual' } `
            -Uri "/groups?`$filter=isAssignableToRole eq true&`$count=true&`$select=$select&`$top=999"

        foreach ($g in $groups) {
            $id = [string](Get-GkDictValue $g 'id')
            $ownerNames = @()
            if ($id) {
                try {
                    $owners = Invoke-GkGraphRequest -CallerFunction 'Get-GkRoleAssignableGroup' -Uri "/groups/$id/owners?`$select=id,displayName"
                    $ownerNames = @($owners | ForEach-Object { [string](Get-GkDictValue $_ 'displayName') } | Where-Object { $_ })
                }
                catch { Write-Verbose "PSGraphKit: owners unavailable for group $id : $($_.Exception.Message)" }
            }

            if ($OwnerlessOnly -and $ownerNames.Count -gt 0) { continue }

            $obj = [ordered]@{
                PSTypeName  = 'PSGraphKit.RoleAssignableGroup'
                DisplayName = [string](Get-GkDictValue $g 'displayName')
                Owners      = if ($AsReport) { $ownerNames -join '; ' } else { , $ownerNames }
                OwnerCount  = $ownerNames.Count
                IsOwnerless = ($ownerNames.Count -eq 0)
                Visibility  = [string](Get-GkDictValue $g 'visibility')
                Id          = $id
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
