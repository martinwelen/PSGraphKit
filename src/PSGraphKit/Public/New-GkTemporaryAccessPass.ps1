function New-GkTemporaryAccessPass {
    <#
    .SYNOPSIS
        Issue a Temporary Access Pass so a user can register a strong credential.

    .DESCRIPTION
        Calls POST /users/{id}/authentication/temporaryAccessPassMethods. A TAP is a time-boxed
        passcode that satisfies MFA once, which is how you onboard someone to a passkey or recover
        an account that has lost every method — without handing out a standing password.

        The passcode is returned as plain text on the result but is NOT shown by the default view,
        so it does not splash across the screen or into a transcript. Capture it deliberately with
        Select-Object TemporaryAccessPass. It cannot be retrieved again.

        A user can hold only one TAP at a time; issuing a second fails until the first is deleted or
        expires. State-changing: supports -WhatIf / -Confirm and prompts by default.

        Requires UserAuthMethod-TAP.ReadWrite.All (or UserAuthenticationMethod.ReadWrite.All). The
        read-only and non-.All variants Graph lists are not accepted here: they cannot create, or
        they cover only the signed-in user's own methods. The Temporary Access Pass authentication
        method must also be enabled in the tenant's authentication methods policy — check with
        Get-GkAuthMethodPolicy.

    .PARAMETER UserId
        One or more user object IDs or userPrincipalNames. Accepts pipeline input, including by the
        UserPrincipalName / Id property.

    .PARAMETER LifetimeInMinutes
        How long the pass stays valid, from 10 minutes to 43200 (30 days). The tenant policy may
        impose a narrower range. Defaults to 60.

    .PARAMETER StartDateTime
        When the pass becomes valid. Defaults to immediately.

    .PARAMETER Reusable
        Allow the pass to be used more than once within its lifetime. Off by default: a one-time
        pass is the safer choice, and the tenant policy may forbid reusable passes entirely.

    .EXAMPLE
        New-GkTemporaryAccessPass -UserId ada@contoso.com | Select-Object UserId, TemporaryAccessPass

        Issue a one-hour, single-use pass and capture it.

    .EXAMPLE
        New-GkTemporaryAccessPass -UserId ada@contoso.com -LifetimeInMinutes 480 -Reusable

        An eight-hour reusable pass, for someone setting up a new device across a working day.

    .EXAMPLE
        New-GkTemporaryAccessPass -UserId ada@contoso.com -WhatIf

    .OUTPUTS
        PSGraphKit.TemporaryAccessPassResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('PSGraphKit.TemporaryAccessPassResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserPrincipalName', 'Id')]
        [string[]] $UserId,

        [ValidateRange(10, 43200)]
        [int] $LifetimeInMinutes = 60,

        [datetime] $StartDateTime,

        [switch] $Reusable
    )

    begin {
        Test-GkConnection -FunctionName 'New-GkTemporaryAccessPass' -Caller $PSCmdlet | Out-Null
    }

    process {
        foreach ($uid in $UserId) {
            if ([string]::IsNullOrWhiteSpace($uid)) { continue }

            $action = "Issue Temporary Access Pass ($LifetimeInMinutes min$(if ($Reusable) { ', reusable' }))"
            if (-not $PSCmdlet.ShouldProcess($uid, $action)) { continue }

            $body = @{
                lifetimeInMinutes = $LifetimeInMinutes
                isUsableOnce      = -not $Reusable
            }
            if ($PSBoundParameters.ContainsKey('StartDateTime')) {
                $body['startDateTime'] = $StartDateTime.ToUniversalTime().ToString('o')
            }

            $enc = [uri]::EscapeDataString($uid)
            $outcome = 'Created'
            $errMsg = $null
            $pass = $null
            $starts = $null
            $methodId = $null
            try {
                $resp = Invoke-GkGraphRequest -Raw -Method POST -Uri "/users/$enc/authentication/temporaryAccessPassMethods" `
                    -Body $body -CallerFunction 'New-GkTemporaryAccessPass'
                $pass = [string](Get-GkDictValue $resp 'temporaryAccessPass')
                $starts = ConvertTo-GkDateTime (Get-GkDictValue $resp 'startDateTime')
                $methodId = [string](Get-GkDictValue $resp 'id')
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to issue a Temporary Access Pass for '$uid': $errMsg"
            }

            $expires = if ($null -ne $starts) { $starts.AddMinutes($LifetimeInMinutes) } else { $null }

            [pscustomobject]@{
                PSTypeName          = 'PSGraphKit.TemporaryAccessPassResult'
                UserId              = $uid
                Action              = 'CreateTemporaryAccessPass'
                Outcome             = $outcome
                LifetimeInMinutes   = $LifetimeInMinutes
                IsUsableOnce        = (-not $Reusable)
                StartDateTime       = $starts
                ExpiresDateTime     = $expires
                TemporaryAccessPass = $pass
                MethodId            = $methodId
                Error               = $errMsg
            }
        }
    }
}
