function Remove-GkConsentGrant {
    <#
    .SYNOPSIS
        Revoke a delegated OAuth2 permission grant (consent).

    .DESCRIPTION
        Deletes an oauth2PermissionGrant (DELETE /oauth2PermissionGrants/{id}), revoking a delegated
        permission consent — for example an over-privileged tenant-wide (AllPrincipals) grant surfaced
        by Get-GkServicePrincipalReport -IncludeConsentGrants.

        State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts grant IDs from the
        pipeline and yields a PSGraphKit.ConsentGrantRemovalResult per grant; failures warn and continue.
        Requires DelegatedPermissionGrant.ReadWrite.All.

        Grant IDs come from GET /oauth2PermissionGrants (e.g. via Invoke-MgGraphRequest) — this cmdlet
        performs the revoke once you have the id.

    .PARAMETER GrantId
        One or more oauth2PermissionGrant IDs to delete. Accepts pipeline input (incl. by the Id property).

    .EXAMPLE
        Remove-GkConsentGrant -GrantId $grantId -WhatIf

        Preview revoking one consent grant.

    .EXAMPLE
        $grants = (Invoke-MgGraphRequest GET 'https://graph.microsoft.com/v1.0/oauth2PermissionGrants' -OutputType PSObject).value |
            Where-Object consentType -eq 'AllPrincipals'
        $grants.id | Remove-GkConsentGrant -Confirm:$false

        Revoke every tenant-wide delegated consent.

    .EXAMPLE
        Remove-GkConsentGrant -GrantId $id -Confirm:$false | Format-List GrantId, Outcome, Error

    .OUTPUTS
        PSGraphKit.ConsentGrantRemovalResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.ConsentGrantRemovalResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string[]] $GrantId
    )

    begin {
        Test-GkConnection -FunctionName 'Remove-GkConsentGrant' -Caller $PSCmdlet | Out-Null
    }

    process {
        foreach ($gid in $GrantId) {
            if ([string]::IsNullOrWhiteSpace($gid)) { continue }
            if (-not $PSCmdlet.ShouldProcess($gid, 'Revoke OAuth2 permission grant')) { continue }

            $enc = [uri]::EscapeDataString($gid)
            $outcome = 'Revoked'
            $errMsg = $null
            try {
                Invoke-GkGraphRequest -Method DELETE -Uri "/oauth2PermissionGrants/$enc" -CallerFunction 'Remove-GkConsentGrant' | Out-Null
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to revoke consent grant '$gid': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName = 'PSGraphKit.ConsentGrantRemovalResult'
                GrantId    = $gid
                Action     = 'RevokeConsentGrant'
                Outcome    = $outcome
                Error      = $errMsg
            }
        }
    }
}
