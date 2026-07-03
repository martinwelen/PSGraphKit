function Revoke-GkUserSession {
    <#
    .SYNOPSIS
        Revoke the active sign-in sessions (refresh tokens) of one or more users, forcing
        re-authentication.

    .DESCRIPTION
        Calls POST /users/{id}/revokeSignInSessions, which resets the user's
        signInSessionsValidFromDateTime so existing tokens can no longer be refreshed. Useful for
        offboarding, suspected compromise, or after a password reset.

        This is a state-changing operation: it supports -WhatIf / -Confirm and prompts by default.
        Accepts users from the pipeline, so it composes with the reporting cmdlets. Each processed
        user yields a PSGraphKit.SessionRevokeResult; a failure warns and continues rather than
        aborting a bulk run.

        Notes: external/B2B guests are not affected (they authenticate in their home tenant), and
        revocation takes a few minutes to propagate. Requires the User.RevokeSessions.All scope
        (plus a supporting Entra role, e.g. User Administrator, to act on other users).

    .PARAMETER UserId
        One or more user object IDs or userPrincipalNames. Accepts pipeline input, including by the
        UserPrincipalName / Id property so report output can be piped in.

    .EXAMPLE
        Revoke-GkUserSession -UserId ada@contoso.com

        Revoke one user's sessions (prompts for confirmation).

    .EXAMPLE
        Get-GkStaleUser -InactiveDays 180 | Revoke-GkUserSession -WhatIf

        Preview revoking sessions for every user stale 180+ days, without making changes.

    .EXAMPLE
        'ada@contoso.com','bob@contoso.com' | Revoke-GkUserSession -Confirm:$false |
            Where-Object Outcome -eq 'Failed'

        Revoke without prompting and inspect any failures.

    .OUTPUTS
        PSGraphKit.SessionRevokeResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.SessionRevokeResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserPrincipalName', 'Id')]
        [string[]] $UserId
    )

    begin {
        Test-GkConnection -FunctionName 'Revoke-GkUserSession' | Out-Null
    }

    process {
        foreach ($uid in $UserId) {
            if ([string]::IsNullOrWhiteSpace($uid)) { continue }

            if (-not $PSCmdlet.ShouldProcess($uid, 'Revoke sign-in sessions')) { continue }

            # Percent-encode the id so guest UPNs containing '#' are not truncated.
            $enc = [uri]::EscapeDataString($uid)

            $outcome = 'Revoked'
            $errMsg = $null
            try {
                Invoke-GkGraphRequest -Method POST -Uri "/users/$enc/revokeSignInSessions" `
                    -CallerFunction 'Revoke-GkUserSession' | Out-Null
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to revoke sessions for '$uid': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName = 'PSGraphKit.SessionRevokeResult'
                UserId     = $uid
                Action     = 'RevokeSignInSessions'
                Outcome    = $outcome
                Error      = $errMsg
            }
        }
    }
}
