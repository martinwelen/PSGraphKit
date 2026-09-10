function Get-GkLicenseAssignmentError {
    <#
    .SYNOPSIS
        Report users whose license assignments are in an error state.

    .DESCRIPTION
        Reads GET /users?$select=licenseAssignmentStates and emits one row per (user, failing SKU)
        where the state is Error or ActiveWithError — for example count/dependency violations or a
        usage-location problem. Group-based licensing failures are identified by AssignedByGroup.
        SKU GUIDs are resolved to part numbers via /subscribedSkus.

        Requires User.Read.All (and Organization.Read.All / Directory.Read.All to resolve SKU names).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkLicenseAssignmentError

        All users with a failing license assignment, one row per erroring SKU.

    .EXAMPLE
        Get-GkLicenseAssignmentError | Where-Object AssignedByGroup

        Failures coming from group-based licensing (fix at the group, not the user).

    .EXAMPLE
        Get-GkLicenseAssignmentError -AsReport | Export-Csv .\license-errors.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.LicenseAssignmentError
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.LicenseAssignmentError')]
    param(
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkLicenseAssignmentError' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        # SKU GUID -> part number map.
        $skuMap = @{}
        foreach ($sku in (Invoke-GkGraphRequest -Uri '/subscribedSkus' -CallerFunction 'Get-GkLicenseAssignmentError')) {
            $sid = [string](Get-GkDictValue $sku 'skuId')
            if ($sid) { $skuMap[$sid] = [string](Get-GkDictValue $sku 'skuPartNumber') }
        }

        $users = Invoke-GkGraphRequest -Uri '/users?$select=id,userPrincipalName,licenseAssignmentStates&$top=999' -CallerFunction 'Get-GkLicenseAssignmentError'

        foreach ($u in $users) {
            foreach ($state in @(Get-GkDictValue $u 'licenseAssignmentStates')) {
                $s = [string](Get-GkDictValue $state 'state')
                if ($s -notin @('Error', 'ActiveWithError')) { continue }

                $skuId = [string](Get-GkDictValue $state 'skuId')
                $part = if ($skuMap.ContainsKey($skuId)) { $skuMap[$skuId] } else { $skuId }
                $friendly = if ($script:GkSkuFriendlyName.ContainsKey($part)) { $script:GkSkuFriendlyName[$part] } else { $part }
                $group = [string](Get-GkDictValue $state 'assignedByGroup')

                $obj = [ordered]@{
                    PSTypeName        = 'PSGraphKit.LicenseAssignmentError'
                    UserPrincipalName = [string](Get-GkDictValue $u 'userPrincipalName')
                    SkuPartNumber     = $part
                    FriendlyName      = $friendly
                    State             = $s
                    ErrorCode         = [string](Get-GkDictValue $state 'error')
                    AssignedByGroup   = [bool]$group
                    GroupId           = $group
                    UserId            = [string](Get-GkDictValue $u 'id')
                    SkuId             = $skuId
                }
                if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
                [pscustomobject]$obj
            }
        }
    }
}
