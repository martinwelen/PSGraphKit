function Remove-GkUserLicense {
    <#
    .SYNOPSIS
        Remove one or more license SKUs from users, reclaiming the seats.

    .DESCRIPTION
        Calls POST /users/{id}/assignLicense with the SKU(s) in removeLicenses, releasing those
        licenses from the user. Typically used to reclaim licenses from disabled or stale accounts.

        State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts users from the
        pipeline and yields a PSGraphKit.LicenseRemoveResult per user; a failure warns and continues.

        SKU GUIDs come from Get-GkLicenseOverview (the SkuId column). Note: a license assigned via
        group-based licensing cannot be removed per user — that returns a Graph error (reported as a
        Failed result); change the group assignment instead.

        Requires LicenseAssignment.ReadWrite.All (or Directory.ReadWrite.All / User.ReadWrite.All)
        plus a supporting Entra role (e.g. License Administrator or User Administrator).

    .PARAMETER UserId
        One or more user object IDs or userPrincipalNames. Accepts pipeline input (incl. by the
        UserPrincipalName / Id property).

    .PARAMETER SkuId
        One or more SKU GUIDs to remove (from Get-GkLicenseOverview's SkuId).

    .EXAMPLE
        Remove-GkUserLicense -UserId ada@contoso.com -SkuId 6fd2c87f-b296-42f0-b197-1e91e994b900

        Remove one SKU from one user (prompts for confirmation).

    .EXAMPLE
        $e3 = (Get-GkLicenseOverview | Where-Object SkuPartNumber -eq 'ENTERPRISEPACK').SkuId
        Get-GkStaleUser -InactiveDays 365 | Remove-GkUserLicense -SkuId $e3 -WhatIf

        Preview reclaiming Office 365 E3 from users stale 365+ days.

    .EXAMPLE
        'ada@contoso.com','bob@contoso.com' | Remove-GkUserLicense -SkuId $skuId -Confirm:$false |
            Where-Object Outcome -eq 'Failed'

        Remove a SKU from several users without prompting and inspect any failures.

    .OUTPUTS
        PSGraphKit.LicenseRemoveResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.LicenseRemoveResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserPrincipalName', 'Id')]
        [string[]] $UserId,

        [Parameter(Mandatory)]
        [Alias('RemoveSkuId')]
        [string[]] $SkuId
    )

    begin {
        Test-GkConnection -FunctionName 'Remove-GkUserLicense' -Caller $PSCmdlet | Out-Null
    }

    process {
        foreach ($uid in $UserId) {
            if ([string]::IsNullOrWhiteSpace($uid)) { continue }

            if (-not $PSCmdlet.ShouldProcess($uid, "Remove license(s): $($SkuId -join ', ')")) { continue }

            $enc = [uri]::EscapeDataString($uid)

            $outcome = 'Removed'
            $errMsg = $null
            try {
                Invoke-GkGraphRequest -Method POST -Uri "/users/$enc/assignLicense" `
                    -Body @{ addLicenses = @(); removeLicenses = @($SkuId) } `
                    -CallerFunction 'Remove-GkUserLicense' | Out-Null
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to remove license(s) from '$uid': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName = 'PSGraphKit.LicenseRemoveResult'
                UserId     = $uid
                Action     = 'RemoveLicense'
                SkuId      = ($SkuId -join '; ')
                Outcome    = $outcome
                Error      = $errMsg
            }
        }
    }
}
