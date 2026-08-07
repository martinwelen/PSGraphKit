function Get-GkStaleAppCredential {
    <#
    .SYNOPSIS
        Report app credentials (secrets/certificates) that have never been used or are long unused.

    .DESCRIPTION
        Reads GET /reports/appCredentialSignInActivities (beta) and reports the last time each app
        credential authenticated, so unused secrets/certs can be removed. App display names are
        resolved from /servicePrincipals.

        BETA endpoint (no v1.0 equivalent), global-cloud only. Requires AuditLog.Read.All.
        Unavailable data warns and returns nothing.

    .PARAMETER InactiveDays
        Staleness threshold in days (default 90).

    .PARAMETER StaleOnly
        Return only credentials that are stale (unused >= InactiveDays or never used).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkStaleAppCredential | Where-Object NeverUsed

        App credentials that have never authenticated — prime removal candidates.

    .EXAMPLE
        Get-GkStaleAppCredential -InactiveDays 180 -StaleOnly

        Credentials unused for 180+ days.

    .EXAMPLE
        Get-GkStaleAppCredential -AsReport | Export-Csv .\stale-credentials.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.StaleAppCredential
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.StaleAppCredential')]
    param(
        [ValidateRange(1, 3650)]
        [int] $InactiveDays = 90,

        [switch] $StaleOnly,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkStaleAppCredential' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        try {
            $creds = Invoke-GkGraphRequest -ApiVersion beta -Uri '/reports/appCredentialSignInActivities' -CallerFunction 'Get-GkStaleAppCredential'
        }
        catch {
            Write-Warning "Could not read app credential sign-in activities (beta report, requires AuditLog.Read.All, global cloud only). $($_.Exception.Message)"
            return
        }

        $nameByAppId = @{}
        foreach ($sp in (Invoke-GkGraphRequest -Uri '/servicePrincipals?$select=appId,displayName&$top=999' -CallerFunction 'Get-GkStaleAppCredential')) {
            $aid = [string](Get-GkDictValue $sp 'appId')
            if ($aid) { $nameByAppId[$aid] = [string](Get-GkDictValue $sp 'displayName') }
        }

        foreach ($c in $creds) {
            $appId = [string](Get-GkDictValue $c 'appId')
            $last  = ConvertTo-GkDateTime (Get-GkDictValue (Get-GkDictValue $c 'signInActivity') 'lastSignInDateTime')
            $never = ($null -eq $last)
            $inactive = if ($never) { $null } else { [int][math]::Floor(($now - $last).TotalDays) }
            $isStale = $never -or ($inactive -ge $InactiveDays)
            if ($StaleOnly -and -not $isStale) { continue }

            $obj = [ordered]@{
                PSTypeName       = 'PSGraphKit.StaleAppCredential'
                AppDisplayName   = if ($nameByAppId.ContainsKey($appId)) { $nameByAppId[$appId] } else { $appId }
                AppId            = $appId
                KeyId            = [string](Get-GkDictValue $c 'keyId')
                KeyType          = [string](Get-GkDictValue $c 'keyType')
                CredentialOrigin = [string](Get-GkDictValue $c 'credentialOrigin')
                LastUsed         = $last
                InactiveDays     = $inactive
                NeverUsed        = $never
                IsStale          = $isStale
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
