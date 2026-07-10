function Get-GkConsentRequest {
    <#
    .SYNOPSIS
        Report pending admin-consent requests (apps waiting for an administrator to grant
        permissions).

    .DESCRIPTION
        Reads GET /identityGovernance/appConsent/appConsentRequests — apps for which users have
        requested admin consent. Requires the admin-consent workflow to be enabled in the tenant.

        Requires the ConsentRequest.Read.All scope. Unavailable data warns and returns nothing.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkConsentRequest

        Apps awaiting admin consent, with the number of pending permission scopes.

    .EXAMPLE
        Get-GkConsentRequest | Where-Object PendingScopeCount -gt 0 | Sort-Object AppDisplayName

    .EXAMPLE
        Get-GkConsentRequest -AsReport | Export-Csv .\consent-requests.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.ConsentRequest
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.ConsentRequest')]
    param(
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkConsentRequest' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        try {
            $requests = Invoke-GkGraphRequest -Uri '/identityGovernance/appConsent/appConsentRequests' -CallerFunction 'Get-GkConsentRequest'
        }
        catch {
            Write-Warning "Could not read admin-consent requests. Requires ConsentRequest.Read.All and the admin-consent workflow to be enabled. $($_.Exception.Message)"
            return
        }

        foreach ($r in $requests) {
            # appConsentRequest has no pendingScopeCount/consentType properties — the pending permissions
            # live in the pendingScopes collection. Count and name them from there.
            $pending    = @(Get-GkDictValue $r 'pendingScopes')
            $scopeNames = @($pending | ForEach-Object { [string](Get-GkDictValue $_ 'displayName') } | Where-Object { $_ })
            $obj = [ordered]@{
                PSTypeName        = 'PSGraphKit.ConsentRequest'
                AppDisplayName    = [string](Get-GkDictValue $r 'appDisplayName')
                AppId             = [string](Get-GkDictValue $r 'appId')
                PendingScopeCount = $pending.Count
                PendingScopes     = if ($AsReport) { $scopeNames -join '; ' } else { , $scopeNames }
                Id                = [string](Get-GkDictValue $r 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
