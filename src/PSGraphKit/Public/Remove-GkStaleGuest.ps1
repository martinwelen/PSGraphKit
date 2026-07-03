function Remove-GkStaleGuest {
    <#
    .SYNOPSIS
        Disable (default) or delete stale guest accounts, with a guest-type safety check.

    .DESCRIPTION
        By default blocks sign-in (PATCH /users/{id} accountEnabled=false). With -Delete it instead
        deletes the account (DELETE /users/{id}); deletion is a 30-day soft-delete, recoverable from
        the directory's deleted items. Permanent purge is intentionally NOT offered here — do it
        deliberately.

        Safety: unless -Force is given, each account is verified to be a guest (userType eq 'Guest')
        before any change, and members are skipped with a warning — so piping the wrong objects in
        cannot accidentally disable/delete a member.

        State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts users from the
        pipeline and yields a PSGraphKit.GuestRemovalResult per user; failures warn and continue.
        Requires User.ReadWrite.All (or Directory.ReadWrite.All) plus a supporting Entra role.

    .PARAMETER UserId
        One or more user object IDs or userPrincipalNames (accepts pipeline input, incl. by the
        UserPrincipalName / Id property).

    .PARAMETER Delete
        Delete the account (soft-delete) instead of only disabling it.

    .PARAMETER Force
        Skip the guest-type safety check (act on the user regardless of userType).

    .EXAMPLE
        Get-GkGuestInventory -StaleOnly -InactiveDays 180 | Remove-GkStaleGuest -WhatIf

        Preview disabling guests inactive 180+ days.

    .EXAMPLE
        Get-GkGuestInventory -StaleOnly -InactiveDays 365 | Remove-GkStaleGuest -Delete -Confirm:$false

        Soft-delete guests inactive 365+ days.

    .EXAMPLE
        Remove-GkStaleGuest -UserId guest_ext#EXT#@contoso.onmicrosoft.com

        Disable one guest (prompts for confirmation).

    .OUTPUTS
        PSGraphKit.GuestRemovalResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.GuestRemovalResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserPrincipalName', 'Id')]
        [string[]] $UserId,

        [switch] $Delete,

        [switch] $Force
    )

    begin {
        Test-GkConnection -FunctionName 'Remove-GkStaleGuest' | Out-Null
    }

    process {
        foreach ($uid in $UserId) {
            if ([string]::IsNullOrWhiteSpace($uid)) { continue }
            $enc = [uri]::EscapeDataString($uid)
            $action = if ($Delete) { 'Delete guest (soft-delete)' } else { 'Disable guest (accountEnabled = false)' }

            # Guest-type safety check (unless -Force).
            if (-not $Force) {
                try {
                    $u = Invoke-GkGraphRequest -Raw -Uri "/users/$enc`?`$select=id,userType" -CallerFunction 'Remove-GkStaleGuest'
                    $utype = [string](Get-GkDictValue $u 'userType')
                    if ($utype -ne 'Guest') {
                        Write-Warning "Skipping '$uid': not a guest (userType=$utype). Use -Force to override."
                        [pscustomobject]@{ PSTypeName = 'PSGraphKit.GuestRemovalResult'; UserId = $uid; Action = 'Skipped'; Outcome = 'Skipped'; Error = "Not a guest (userType=$utype)" }
                        continue
                    }
                }
                catch {
                    Write-Warning "Skipping '$uid': could not verify guest status. $($_.Exception.Message)"
                    [pscustomobject]@{ PSTypeName = 'PSGraphKit.GuestRemovalResult'; UserId = $uid; Action = 'Skipped'; Outcome = 'Failed'; Error = $_.Exception.Message }
                    continue
                }
            }

            if (-not $PSCmdlet.ShouldProcess($uid, $action)) { continue }

            $outcome = if ($Delete) { 'Deleted' } else { 'Disabled' }
            $errMsg = $null
            try {
                if ($Delete) {
                    Invoke-GkGraphRequest -Method DELETE -Uri "/users/$enc" -CallerFunction 'Remove-GkStaleGuest' | Out-Null
                }
                else {
                    Invoke-GkGraphRequest -Method PATCH -Uri "/users/$enc" -Body @{ accountEnabled = $false } -CallerFunction 'Remove-GkStaleGuest' | Out-Null
                }
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to $(if ($Delete) { 'delete' } else { 'disable' }) '$uid': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName = 'PSGraphKit.GuestRemovalResult'
                UserId     = $uid
                Action     = if ($Delete) { 'SoftDelete' } else { 'DisableAccount' }
                Outcome    = $outcome
                Error      = $errMsg
            }
        }
    }
}
