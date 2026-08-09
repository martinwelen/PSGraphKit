function Reset-GkUserPassword {
    <#
    .SYNOPSIS
        Reset a user's password, optionally forcing a change at next sign-in.

    .DESCRIPTION
        Calls PATCH /users/{id} with a passwordProfile. By default a strong random password is
        generated and returned once on the result object, and the user must change it at next
        sign-in — the safe default for a helpdesk reset.

        The generated password is returned as plain text on the result but is NOT shown by the
        default view, so it does not splash across the screen or into a transcript. Capture it
        deliberately with Select-Object Password, the same way Reset-GkAppCredential surfaces a
        new client secret.

        State-changing: supports -WhatIf / -Confirm and prompts by default.

        Requires User-PasswordProfile.ReadWrite.All — the narrow permission Graph documents for the
        passwordProfile property — or a broader user write scope. The signed-in admin also needs a
        role that outranks the target: User Administrator resets non-admins, and Privileged
        Authentication Administrator is required to reset an administrator.

    .PARAMETER UserId
        One or more user object IDs or userPrincipalNames. Accepts pipeline input, including by the
        UserPrincipalName / Id property so report output can be piped in.

    .PARAMETER NewPassword
        Use this password instead of generating one. It must satisfy the tenant password policy.
        Takes a SecureString, the PowerShell convention for a credential you already hold:
        ConvertTo-SecureString 'value' -AsPlainText -Force.

    .PARAMETER NoForceChange
        Do not require the user to change the password at next sign-in. Off by default because a
        helpdesk-set password that persists is a standing credential.

    .EXAMPLE
        Reset-GkUserPassword -UserId ada@contoso.com | Select-Object UserId, Password

        Reset with a generated password and capture it (it cannot be retrieved again).

    .EXAMPLE
        Reset-GkUserPassword -UserId ada@contoso.com -WhatIf

        Preview the reset without changing anything.

    .EXAMPLE
        Get-GkRiskyUser -RiskLevel high | Reset-GkUserPassword -Confirm:$false |
            Where-Object Outcome -eq 'Failed'

        Reset every high-risk user and inspect the failures.

    .OUTPUTS
        PSGraphKit.PasswordResetResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.PasswordResetResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserPrincipalName', 'Id')]
        [string[]] $UserId,

        [securestring] $NewPassword,

        [switch] $NoForceChange
    )

    begin {
        Test-GkConnection -FunctionName 'Reset-GkUserPassword' -Caller $PSCmdlet | Out-Null
        $forceChange = -not $NoForceChange
    }

    process {
        foreach ($uid in $UserId) {
            if ([string]::IsNullOrWhiteSpace($uid)) { continue }

            $action = if ($forceChange) { 'Reset password (change required at next sign-in)' } else { 'Reset password' }
            if (-not $PSCmdlet.ShouldProcess($uid, $action)) { continue }

            # Generate per user, so a bulk reset does not hand every account the same password.
            # The local is deliberately named differently from the parameter: a case-insensitive
            # match would be coerced back to [securestring] on assignment.
            if ($NewPassword) {
                $plainPassword = [System.Net.NetworkCredential]::new('', $NewPassword).Password
            }
            else {
                $plainPassword = New-GkPassword
            }

            $enc = [uri]::EscapeDataString($uid)
            $outcome = 'Reset'
            $errMsg = $null
            try {
                Invoke-GkGraphRequest -Method PATCH -Uri "/users/$enc" -CallerFunction 'Reset-GkUserPassword' -Body @{
                    passwordProfile = @{
                        password                             = $plainPassword
                        forceChangePasswordNextSignIn        = [bool]$forceChange
                    }
                } | Out-Null
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                $plainPassword = $null
                Write-Warning "Failed to reset password for '$uid': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName            = 'PSGraphKit.PasswordResetResult'
                UserId                = $uid
                Action                = 'ResetPassword'
                Outcome               = $outcome
                ForceChangeNextSignIn = [bool]$forceChange
                Password              = $plainPassword
                Error                 = $errMsg
            }
        }
    }
}
