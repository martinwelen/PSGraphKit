function Get-GkGroupBasedLicense {
    <#
    .SYNOPSIS
        Report groups that assign licenses, and whether their assignment has finished processing.

    .DESCRIPTION
        Reads GET /groups selecting assignedLicenses and licenseProcessingState, and returns only
        the groups that actually carry a license assignment. Group-based licensing is invisible in
        most reports until it breaks, and licenseProcessingState is the field that tells you a
        change is still rolling out — or stuck.

        Pairs with Get-GkLicenseAssignmentError, which reports the affected *users*; this reports
        the group that assigned the licence to them. Requires Group.Read.All (or Directory.Read.All).

    .PARAMETER Name
        Only return groups whose display name contains this text (case-insensitive).

    .PARAMETER NotProcessedOnly
        Only return groups whose licenseProcessingState is not ProcessingComplete — the ones still
        rolling out, or stuck.

    .PARAMETER ResolveSkuName
        Resolve each skuId GUID to its SKU part number and friendly name. Costs one extra call to
        /subscribedSkus and therefore needs a second scope (Organization.Read.All or
        Directory.Read.All), which is only validated when you ask for it.

    .PARAMETER First
        Return at most this many groups.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column and flatten the SKU list to a string.

    .EXAMPLE
        Get-GkGroupBasedLicense

        Every group that assigns a licence.

    .EXAMPLE
        Get-GkGroupBasedLicense -NotProcessedOnly

        Group licence assignments that have not finished applying.

    .EXAMPLE
        Get-GkGroupBasedLicense -AsReport | Export-Csv .\group-licensing.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.GroupBasedLicense
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.GroupBasedLicense')]
    param(
        [string] $Name,

        [switch] $NotProcessedOnly,

        [switch] $ResolveSkuName,

        [int] $First,

        [switch] $AsReport
    )

    begin {
        # Resolving SKU names reads /subscribedSkus, which needs a scope the base cmdlet does not.
        $scopeVariant = ''
        if ($ResolveSkuName) { $scopeVariant = 'ResolveSkuName' }
        Test-GkConnection -FunctionName 'Get-GkGroupBasedLicense' -Variant $scopeVariant -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow

        $skuNames = @{}
        if ($ResolveSkuName) {
            try {
                foreach ($s in (Invoke-GkGraphRequest -Uri '/subscribedSkus?$select=skuId,skuPartNumber' -CallerFunction 'Get-GkGroupBasedLicense')) {
                    $skuNames[[string](Get-GkDictValue $s 'skuId')] = [string](Get-GkDictValue $s 'skuPartNumber')
                }
            }
            catch {
                Write-Warning "Could not read /subscribedSkus; reporting skuId GUIDs instead. $($_.Exception.Message)"
            }
        }
    }

    process {
        # assignedLicenses is not filterable server-side, so pull the selected fields and drop the
        # groups with no assignment client-side. The $select keeps the payload small.
        $params = @{
            Uri            = '/groups?$select=id,displayName,assignedLicenses,licenseProcessingState'
            CallerFunction = 'Get-GkGroupBasedLicense'
        }
        if ($PSBoundParameters.ContainsKey('First')) { $params['MaxResult'] = $First }

        $groups = Invoke-GkGraphRequest @params

        foreach ($g in $groups) {
            $assigned = @(Get-GkDictValue $g 'assignedLicenses')
            if ($assigned.Count -eq 0) { continue }

            $display = [string](Get-GkDictValue $g 'displayName')
            if ($Name -and $display -notlike "*$Name*") { continue }

            # licenseProcessingState is an object with a single 'state' property.
            $stateObj = Get-GkDictValue $g 'licenseProcessingState'
            $state = [string](Get-GkDictValue $stateObj 'state')
            if ($NotProcessedOnly -and $state -eq 'ProcessingComplete') { continue }

            $skus = @(
                foreach ($a in $assigned) {
                    $id = [string](Get-GkDictValue $a 'skuId')
                    $part = $skuNames[$id]
                    if (-not $part) { $id }
                    elseif ($script:GkSkuFriendlyName.ContainsKey($part)) { $script:GkSkuFriendlyName[$part] }
                    else { $part }
                }
            )

            $obj = [ordered]@{
                PSTypeName      = 'PSGraphKit.GroupBasedLicense'
                DisplayName     = $display
                LicenseCount    = $assigned.Count
                ProcessingState = if ($state) { $state } else { 'Unknown' }
                IsComplete      = ($state -eq 'ProcessingComplete')
                Id              = [string](Get-GkDictValue $g 'id')
            }
            if ($AsReport) { $obj['Skus'] = ($skus -join '; ') }
            else { $obj['Skus'] = [string[]]@($skus) }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
