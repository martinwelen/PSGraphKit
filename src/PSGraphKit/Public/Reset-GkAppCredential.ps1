function Reset-GkAppCredential {
    <#
    .SYNOPSIS
        Add or remove an app registration's client secret.

    .DESCRIPTION
        Manages application client secrets:
          * Add (default)   POST /applications/{id}/addPassword — returns the new secretText ONCE
            (it cannot be retrieved again, so it is surfaced on the result object). Use -DisplayName
            and -ValidMonths to control the credential.
          * Remove          POST /applications/{id}/removePassword -RemoveKeyId <keyId>.

        Certificate rotation is intentionally not supported: addKey/removeKey require a
        proof-of-possession JWT signed by an existing private key, which is outside this module's
        scope. Manage certificates with a dedicated tool that holds the key material.

        State-changing: supports -WhatIf / -Confirm and prompts by default. Accepts applications from
        the pipeline (by the Id property, i.e. the application OBJECT id from
        Get-GkAppRegistrationReport) and yields a PSGraphKit.AppCredentialResult per application.
        Requires Application.ReadWrite.All plus a supporting Entra role (e.g. Application Administrator).

    .PARAMETER ApplicationId
        One or more application OBJECT IDs (the Id from Get-GkAppRegistrationReport, not AppId).

    .PARAMETER DisplayName
        Friendly name for the new secret (Add set). Default 'PSGraphKit secret'.

    .PARAMETER ValidMonths
        Lifetime of the new secret in months (Add set). Default 12.

    .PARAMETER RemoveKeyId
        keyId of the secret to remove (Remove set).

    .EXAMPLE
        Reset-GkAppCredential -ApplicationId $appObjectId -DisplayName 'rotated 2026' -Confirm:$false |
            Select-Object ApplicationId, KeyId, SecretText

        Add a new client secret and capture the generated value (shown once).

    .EXAMPLE
        Reset-GkAppCredential -ApplicationId $appObjectId -RemoveKeyId $oldKeyId -WhatIf

        Preview removing a specific secret.

    .EXAMPLE
        Get-GkAppRegistrationReport -ExpiringOnly | Reset-GkAppCredential -WhatIf

        Preview adding a fresh secret to every app with an expiring credential.

    .OUTPUTS
        PSGraphKit.AppCredentialResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'AddSecret')]
    [OutputType('PSGraphKit.AppCredentialResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string[]] $ApplicationId,

        [Parameter(ParameterSetName = 'AddSecret')]
        [string] $DisplayName = 'PSGraphKit secret',

        [Parameter(ParameterSetName = 'AddSecret')]
        [ValidateRange(1, 24)]
        [int] $ValidMonths = 12,

        [Parameter(Mandatory, ParameterSetName = 'RemoveSecret')]
        [string] $RemoveKeyId
    )

    begin {
        Test-GkConnection -FunctionName 'Reset-GkAppCredential' -Caller $PSCmdlet | Out-Null
        $isRemove = $PSCmdlet.ParameterSetName -eq 'RemoveSecret'
    }

    process {
        foreach ($appId in $ApplicationId) {
            if ([string]::IsNullOrWhiteSpace($appId)) { continue }
            $enc = [uri]::EscapeDataString($appId)

            $action = if ($isRemove) { "Remove client secret $RemoveKeyId" } else { "Add client secret ($DisplayName, ${ValidMonths}mo)" }
            if (-not $PSCmdlet.ShouldProcess($appId, $action)) { continue }

            $outcome = if ($isRemove) { 'SecretRemoved' } else { 'SecretAdded' }
            $keyId = if ($isRemove) { $RemoveKeyId } else { $null }
            $secretText = $null
            $endDate = $null
            $errMsg = $null

            try {
                if ($isRemove) {
                    Invoke-GkGraphRequest -Method POST -Uri "/applications/$enc/removePassword" `
                        -Body @{ keyId = $RemoveKeyId } -CallerFunction 'Reset-GkAppCredential' | Out-Null
                }
                else {
                    $end = [datetime]::UtcNow.AddMonths($ValidMonths).ToString('o')
                    $resp = Invoke-GkGraphRequest -Raw -Method POST -Uri "/applications/$enc/addPassword" `
                        -Body @{ passwordCredential = @{ displayName = $DisplayName; endDateTime = $end } } `
                        -CallerFunction 'Reset-GkAppCredential'
                    $secretText = [string](Get-GkDictValue $resp 'secretText')
                    $keyId = [string](Get-GkDictValue $resp 'keyId')
                    $endDate = ConvertTo-GkDateTime (Get-GkDictValue $resp 'endDateTime')
                }
            }
            catch {
                $outcome = 'Failed'
                $errMsg = $_.Exception.Message
                Write-Warning "Failed to $(if ($isRemove) { 'remove secret from' } else { 'add secret to' }) app '$appId': $errMsg"
            }

            [pscustomobject]@{
                PSTypeName    = 'PSGraphKit.AppCredentialResult'
                ApplicationId = $appId
                Action        = if ($isRemove) { 'RemoveSecret' } else { 'AddSecret' }
                KeyId         = $keyId
                SecretText    = $secretText
                EndDateTime   = $endDate
                Outcome       = $outcome
                Error         = $errMsg
            }
        }
    }
}
