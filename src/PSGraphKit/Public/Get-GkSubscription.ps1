function Get-GkSubscription {
    <#
    .SYNOPSIS
        Report tenant subscriptions with their renewal/expiry date and status.

    .DESCRIPTION
        Reads GET /directory/subscriptions (companySubscription), which — unlike /subscribedSkus —
        includes the lifecycle date. nextLifecycleDateTime is the next renewal/expiry, so this fills
        the "when do our licenses lapse" gap. Requires the Organization.Read.All scope.

    .PARAMETER ExpiringInDays
        Only return subscriptions whose next lifecycle date is within this many days (e.g. 60).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkSubscription | Sort-Object NextLifecycleDate

        Subscriptions by upcoming renewal/expiry.

    .EXAMPLE
        Get-GkSubscription -ExpiringInDays 60

        Subscriptions renewing or expiring within 60 days.

    .EXAMPLE
        Get-GkSubscription -AsReport | Export-Csv .\subscriptions.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.Subscription
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.Subscription')]
    param(
        [int] $ExpiringInDays,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkSubscription' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $subs = Invoke-GkGraphRequest -Uri '/directory/subscriptions' -CallerFunction 'Get-GkSubscription'

        foreach ($s in $subs) {
            $part = [string](Get-GkDictValue $s 'skuPartNumber')
            $next = ConvertTo-GkDateTime (Get-GkDictValue $s 'nextLifecycleDateTime')
            $days = if ($null -ne $next) { [int][math]::Floor(($next - $now).TotalDays) } else { $null }

            if ($PSBoundParameters.ContainsKey('ExpiringInDays')) {
                if ($null -eq $days -or $days -gt $ExpiringInDays) { continue }
            }

            $obj = [ordered]@{
                PSTypeName        = 'PSGraphKit.Subscription'
                SkuPartNumber     = $part
                FriendlyName      = if ($script:GkSkuFriendlyName.ContainsKey($part)) { $script:GkSkuFriendlyName[$part] } else { $part }
                Status            = [string](Get-GkDictValue $s 'status')
                TotalLicenses     = [int](Get-GkDictValue $s 'totalLicenses')
                IsTrial           = [bool](Get-GkDictValue $s 'isTrial')
                NextLifecycleDate = $next
                DaysUntilRenewal  = $days
                CreatedDateTime   = ConvertTo-GkDateTime (Get-GkDictValue $s 'createdDateTime')
                Id                = [string](Get-GkDictValue $s 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
