function Get-GkAuthMethodPolicy {
    <#
    .SYNOPSIS
        Report the tenant authentication-methods policy: which methods are enabled or disabled.

    .DESCRIPTION
        Reads GET /policies/authenticationMethodsPolicy and emits one row per authentication method
        configuration (fido2, microsoftAuthenticator, sms, temporaryAccessPass, softwareOath, email,
        voice, x509Certificate, ...) with its state. Useful for confirming which methods a tenant
        permits.

        Requires Policy.Read.AuthenticationMethod (or Policy.Read.All).

    .PARAMETER EnabledOnly
        Return only methods whose state is 'enabled'.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkAuthMethodPolicy | Sort-Object State, Method

        All methods with their enabled/disabled state.

    .EXAMPLE
        Get-GkAuthMethodPolicy -EnabledOnly

        Only the methods currently enabled in the tenant.

    .EXAMPLE
        Get-GkAuthMethodPolicy -AsReport | Export-Csv .\auth-methods.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.AuthMethodState
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.AuthMethodState')]
    param(
        [switch] $EnabledOnly,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkAuthMethodPolicy' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $policy = Invoke-GkGraphRequest -Raw -Uri '/policies/authenticationMethodsPolicy' -CallerFunction 'Get-GkAuthMethodPolicy'
        $configs = @(Get-GkDictValue $policy 'authenticationMethodConfigurations')

        foreach ($c in $configs) {
            $state = [string](Get-GkDictValue $c 'state')
            if ($EnabledOnly -and $state -ne 'enabled') { continue }

            # Derive a friendly method name from the id or @odata.type.
            $method = [string](Get-GkDictValue $c 'id')
            if (-not $method) {
                $odataType = [string](Get-GkDictValue $c '@odata.type')
                if ($odataType) { $method = ($odataType -split '\.')[-1] -replace 'AuthenticationMethodConfiguration$', '' }
            }

            $obj = [ordered]@{
                PSTypeName = 'PSGraphKit.AuthMethodState'
                Method     = $method
                State      = $state
                Id         = [string](Get-GkDictValue $c 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
