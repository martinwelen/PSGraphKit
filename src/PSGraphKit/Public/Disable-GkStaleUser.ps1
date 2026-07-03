function Disable-GkStaleUser {
    <#
    .SYNOPSIS
        Block sign-in for one or more users by setting accountEnabled = false.

    .DESCRIPTION
        Calls PATCH /users/{id} with { "accountEnabled": false }, blocking the account from signing
        in. Typically fed from Get-GkStaleUser to remediate stale accounts, but it acts on whatever
        users are supplied.

        State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts users from the
        pipeline and yields a PSGraphKit.UserDisableResult per user; a failure warns and continues.
        Disabling is reversible (set accountEnabled back to true). Blocking a privileged/admin
        account requires a higher Entra role than blocking a regular user.

        Requires User.EnableDisableAccount.All (or User.ReadWrite.All / Directory.ReadWrite.All) plus
        a supporting Entra role (e.g. User Administrator).

    .PARAMETER UserId
        One or more user object IDs or userPrincipalNames. Accepts pipeline input, including by the
        UserPrincipalName / Id property so report output can be piped in.

    .EXAMPLE
        Disable-GkStaleUser -UserId ada@contoso.com

        Block one user (prompts for confirmation).

    .EXAMPLE
        Get-GkStaleUser -InactiveDays 180 | Where-Object { -not $_.IsGuest } | Disable-GkStaleUser -WhatIf

        Preview blocking every non-guest user stale 180+ days, without making changes.

    .EXAMPLE
        Get-GkStaleUser -InactiveDays 365 | Disable-GkStaleUser -Confirm:$false |
            Where-Object Outcome -eq 'Failed'

        Block without prompting and inspect any failures.

    .OUTPUTS
        PSGraphKit.UserDisableResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.UserDisableResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserPrincipalName', 'Id')]
        [string[]] $UserId
    )

    begin {
        Test-GkConnection -FunctionName 'Disable-GkStaleUser' | Out-Null
    }

    process {
        foreach ($uid in $UserId) {
            if ([string]::IsNullOrWhiteSpace($uid)) { continue }

            if (-not $PSCmdlet.ShouldProcess($uid, 'Block sign-in (accountEnabled = false)')) { continue }

            $enc = [uri]::EscapeDataString($uid)

            $outcome = 'Disabled'
            $errMsg = $null
            try {
                Invoke-GkGraphRequest -Method PATCH -Uri "/users/$enc" -Body @{ accountEnabled = $false } `
                    -CallerFunction 'Disable-GkStaleUser' | Out-Null
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to disable '$uid': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName = 'PSGraphKit.UserDisableResult'
                UserId     = $uid
                Action     = 'DisableAccount'
                Outcome    = $outcome
                Error      = $errMsg
            }
        }
    }
}
