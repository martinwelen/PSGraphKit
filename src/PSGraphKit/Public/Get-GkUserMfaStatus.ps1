function Get-GkUserMfaStatus {
    <#
    .SYNOPSIS
        Report per-user authentication-method registration and MFA capability from the
        authentication methods registration report.

    .DESCRIPTION
        Reads GET /reports/authenticationMethods/userRegistrationDetails, which returns a
        ready-made per-user view of registered methods and capability flags across the tenant in
        a single paged call — preferred over enumerating /users/{id}/authentication/methods per user.

        Capability distinction (per Microsoft Graph):
          * IsMfaCapable    = registered a strong method that is ALLOWED by the auth methods policy.
          * IsMfaRegistered = registered a strong method (not necessarily policy-allowed).
        The data has some latency; LastUpdated (lastUpdatedDateTime) reflects when it was refreshed.

        Requires the AuditLog.Read.All scope (this endpoint does not accept Reports.Read.All).

    .PARAMETER NotMfaCapableOnly
        Return only users who are not MFA-capable (server-side filter isMfaCapable eq false).

    .PARAMETER AdminsOnly
        Return only users flagged as admins (server-side filter isAdmin eq true).

    .PARAMETER AsReport
        Flatten MethodsRegistered to a single '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkUserMfaStatus -NotMfaCapableOnly | Sort-Object UserPrincipalName

        Every user who cannot perform MFA — the gap list.

    .EXAMPLE
        Get-GkUserMfaStatus -AdminsOnly | Where-Object { -not $_.IsMfaCapable }

        Admins without MFA capability — a priority remediation set.

    .EXAMPLE
        Get-GkUserMfaStatus -AsReport | Export-Csv .\mfa-status.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.UserMfaStatus
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.UserMfaStatus')]
    param(
        [switch] $NotMfaCapableOnly,

        [switch] $AdminsOnly,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkUserMfaStatus' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $filters = @()
        if ($NotMfaCapableOnly) { $filters += 'isMfaCapable eq false' }
        if ($AdminsOnly)        { $filters += 'isAdmin eq true' }

        $uri = '/reports/authenticationMethods/userRegistrationDetails'
        if ($filters.Count -gt 0) { $uri += '?$filter=' + ($filters -join ' and ') }

        $details = Invoke-GkGraphRequest -Uri $uri -CallerFunction 'Get-GkUserMfaStatus'

        foreach ($d in $details) {
            $methods = @(Get-GkDictValue $d 'methodsRegistered')

            $obj = [ordered]@{
                PSTypeName            = 'PSGraphKit.UserMfaStatus'
                UserPrincipalName     = [string](Get-GkDictValue $d 'userPrincipalName')
                DisplayName           = [string](Get-GkDictValue $d 'userDisplayName')
                IsAdmin               = [bool](Get-GkDictValue $d 'isAdmin')
                IsMfaCapable          = [bool](Get-GkDictValue $d 'isMfaCapable')
                IsMfaRegistered       = [bool](Get-GkDictValue $d 'isMfaRegistered')
                IsPasswordlessCapable = [bool](Get-GkDictValue $d 'isPasswordlessCapable')
                IsSsprCapable         = [bool](Get-GkDictValue $d 'isSsprCapable')
                IsSsprRegistered      = [bool](Get-GkDictValue $d 'isSsprRegistered')
                MethodsRegistered     = if ($AsReport) { $methods -join '; ' } else { , $methods }
                MethodCount           = $methods.Count
                UserType              = [string](Get-GkDictValue $d 'userType')
                LastUpdated           = ConvertTo-GkDateTime (Get-GkDictValue $d 'lastUpdatedDateTime')
                Id                    = [string](Get-GkDictValue $d 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
