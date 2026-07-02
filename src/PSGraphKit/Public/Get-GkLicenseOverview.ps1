function Get-GkLicenseOverview {
    <#
    .SYNOPSIS
        Report subscribed license SKUs with enabled/assigned/available counts, and optionally the
        number of disabled-but-licensed users per SKU.

    .DESCRIPTION
        Reads GET /subscribedSkus and returns one row per SKU with the total enabled seats
        (prepaidUnits.enabled), assigned seats (consumedUnits), computed available seats, and the
        warning/suspended/lockedOut unit counts. A best-effort friendly product name is resolved
        from the SKU part number (the raw SkuPartNumber is always included as the source of truth).

        With -IncludeDisabledLicensed, each SKU is additionally cross-referenced against
        GET /users?$filter=assignedLicenses/any(...) to count users who hold the SKU while disabled
        (accountEnabled = false) — a common license-reclamation target. This adds one user query per
        SKU, so it is opt-in.

    .PARAMETER IncludeDisabledLicensed
        For each SKU, count users assigned that SKU whose account is disabled. Adds a
        DisabledLicensedCount column. Requires a scope that can read users (e.g. User.Read.All).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column for clean export.

    .EXAMPLE
        Get-GkLicenseOverview | Sort-Object Available

        All SKUs, scarcest availability first.

    .EXAMPLE
        Get-GkLicenseOverview -IncludeDisabledLicensed |
            Where-Object DisabledLicensedCount -gt 0 |
            Sort-Object DisabledLicensedCount -Descending

        SKUs with the most licenses assigned to disabled accounts (reclamation candidates).

    .EXAMPLE
        Get-GkLicenseOverview -AsReport | Export-Csv .\licenses.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.LicenseOverview
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.LicenseOverview')]
    param(
        [switch] $IncludeDisabledLicensed,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkLicenseOverview' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $skus = Invoke-GkGraphRequest -Uri '/subscribedSkus' -CallerFunction 'Get-GkLicenseOverview'

        foreach ($sku in $skus) {
            $partNumber = [string](Get-GkDictValue $sku 'skuPartNumber')
            $skuId      = [string](Get-GkDictValue $sku 'skuId')
            $assigned   = [int](Get-GkDictValue $sku 'consumedUnits')

            $prepaid  = Get-GkDictValue $sku 'prepaidUnits'
            $enabled  = [int](Get-GkDictValue $prepaid 'enabled')
            $warning  = [int](Get-GkDictValue $prepaid 'warning')
            $suspend  = [int](Get-GkDictValue $prepaid 'suspended')
            $locked   = [int](Get-GkDictValue $prepaid 'lockedOut')

            $servicePlans = @(Get-GkDictValue $sku 'servicePlans')

            $obj = [ordered]@{
                PSTypeName       = 'PSGraphKit.LicenseOverview'
                SkuPartNumber    = $partNumber
                FriendlyName     = if ($script:GkSkuFriendlyName.ContainsKey($partNumber)) { $script:GkSkuFriendlyName[$partNumber] } else { $partNumber }
                Enabled          = $enabled
                Assigned         = $assigned
                Available        = $enabled - $assigned
                Warning          = $warning
                Suspended        = $suspend
                LockedOut        = $locked
                CapabilityStatus = [string](Get-GkDictValue $sku 'capabilityStatus')
                AppliesTo        = [string](Get-GkDictValue $sku 'appliesTo')
                ServicePlanCount = $servicePlans.Count
                SkuId            = $skuId
            }

            if ($IncludeDisabledLicensed) {
                $disabledCount = 0
                if ($skuId) {
                    $uri = "/users?`$filter=assignedLicenses/any(l:l/skuId eq $skuId)&`$select=id,accountEnabled&`$top=999"
                    $licUsers = Invoke-GkGraphRequest -Uri $uri -Headers @{ ConsistencyLevel = 'eventual' } -CallerFunction 'Get-GkLicenseOverview'
                    $disabledCount = @($licUsers | Where-Object { -not [bool](Get-GkDictValue $_ 'accountEnabled') }).Count
                }
                $obj['DisabledLicensedCount'] = $disabledCount
            }

            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
