function Get-GkUserAuthMethod {
    <#
    .SYNOPSIS
        List the authentication methods registered on a user's account.

    .DESCRIPTION
        Reads GET /users/{id}/authentication/methods and returns one row per registered method with
        its type resolved (Microsoft Authenticator, FIDO2, phone, TAP, Windows Hello, password, ...).
        Get-GkUserMfaStatus reports the tenant-wide registration *summary*; this is the per-user
        detail behind it, for when you need to know exactly what an account can sign in with.

        Reading another user's methods requires UserAuthenticationMethod.Read.All. The narrower
        UserAuthenticationMethod.Read grants only the signed-in user's own methods, so it is not
        accepted here.

        No secret material is returned by Graph, but phone numbers and device names are: treat the
        output as sensitive.

    .PARAMETER UserId
        One or more user object IDs or userPrincipalNames. Accepts pipeline input, including by the
        UserPrincipalName / Id property so report output can be piped in.

    .PARAMETER MethodType
        Only return methods of this type (matched against the resolved MethodType column).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkUserAuthMethod -UserId ada@contoso.com

        Every method registered on one account.

    .EXAMPLE
        Get-GkUserMfaStatus | Where-Object { -not $_.IsMfaCapable } | Get-GkUserAuthMethod

        Inspect what the users who are not MFA-capable actually have registered.

    .EXAMPLE
        Get-GkUserAuthMethod -UserId ada@contoso.com -MethodType Fido2

    .OUTPUTS
        PSGraphKit.UserAuthMethod
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.UserAuthMethod')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserPrincipalName', 'Id')]
        [string[]] $UserId,

        [string] $MethodType,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkUserAuthMethod' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow

        # Graph identifies each method only by its @odata.type; map it to something an admin reads.
        $typeNames = @{
            'microsoftAuthenticatorAuthenticationMethod' = 'MicrosoftAuthenticator'
            'phoneAuthenticationMethod'                  = 'Phone'
            'fido2AuthenticationMethod'                  = 'Fido2'
            'passwordAuthenticationMethod'               = 'Password'
            'windowsHelloForBusinessAuthenticationMethod' = 'WindowsHelloForBusiness'
            'temporaryAccessPassAuthenticationMethod'    = 'TemporaryAccessPass'
            'emailAuthenticationMethod'                  = 'Email'
            'softwareOathAuthenticationMethod'           = 'SoftwareOath'
            'x509CertificateAuthenticationMethod'        = 'X509Certificate'
            'platformCredentialAuthenticationMethod'     = 'PlatformCredential'
            'passwordlessMicrosoftAuthenticatorAuthenticationMethod' = 'PasswordlessAuthenticator'
        }
    }

    process {
        foreach ($uid in $UserId) {
            if ([string]::IsNullOrWhiteSpace($uid)) { continue }
            $enc = [uri]::EscapeDataString($uid)

            try {
                $methods = Invoke-GkGraphRequest -Uri "/users/$enc/authentication/methods" -CallerFunction 'Get-GkUserAuthMethod'
            }
            catch {
                Write-Warning "Could not read authentication methods for '$uid': $($_.Exception.Message)"
                continue
            }

            foreach ($m in $methods) {
                $odata = ([string](Get-GkDictValue $m '@odata.type')) -replace '^#microsoft\.graph\.', ''
                $type = if ($odata -and $typeNames.ContainsKey($odata)) { $typeNames[$odata] } elseif ($odata) { $odata } else { 'Unknown' }

                if ($MethodType -and $type -ne $MethodType) { continue }

                # Each method type names its label differently; take whichever is present.
                $detail = ''
                foreach ($f in 'displayName', 'phoneNumber', 'emailAddress', 'model', 'deviceTag') {
                    $v = [string](Get-GkDictValue $m $f)
                    if ($v) { $detail = $v; break }
                }

                $obj = [ordered]@{
                    PSTypeName  = 'PSGraphKit.UserAuthMethod'
                    UserId      = $uid
                    MethodType  = $type
                    Detail      = $detail
                    CreatedDateTime = ConvertTo-GkDateTime (Get-GkDictValue $m 'createdDateTime')
                    Id          = [string](Get-GkDictValue $m 'id')
                }
                if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
                [pscustomobject]$obj
            }
        }
    }
}
