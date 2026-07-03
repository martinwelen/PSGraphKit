function Get-GkLegacyAuthSignIn {
    <#
    .SYNOPSIS
        Report sign-ins that used legacy authentication clients — a prime attack vector.

    .DESCRIPTION
        Reads GET /auditLogs/signIns over the last -Days and keeps only sign-ins whose client app is
        a legacy protocol (Exchange ActiveSync, IMAP, POP, SMTP, MAPI, Other clients, ...). Legacy
        auth cannot enforce MFA, so surfacing which users/apps still use it is a top hardening task.

        Requires AuditLog.Read.All and a Microsoft Entra ID P1/P2 license. Unavailable data warns and
        returns nothing.

    .PARAMETER Days
        Look-back window in days (default 7).

    .PARAMETER SuccessfulOnly
        Return only successful legacy-auth sign-ins (the ones that actually got in).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkLegacyAuthSignIn -Days 7 | Group-Object UserPrincipalName | Sort-Object Count -Descending

        Users still authenticating with legacy protocols in the last week.

    .EXAMPLE
        Get-GkLegacyAuthSignIn -SuccessfulOnly | Select-Object UserPrincipalName, ClientApp, IpAddress

        Successful legacy-auth sign-ins to prioritize blocking.

    .EXAMPLE
        Get-GkLegacyAuthSignIn -AsReport | Export-Csv .\legacy-auth.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.SignIn
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.SignIn')]
    param(
        [ValidateRange(1, 30)]
        [int] $Days = 7,

        [switch] $SuccessfulOnly,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkLegacyAuthSignIn' | Out-Null
        $now = [datetime]::UtcNow
        $legacyClients = @(
            'Exchange ActiveSync', 'IMAP4', 'IMAP', 'POP3', 'POP', 'SMTP', 'Authenticated SMTP', 'MAPI',
            'Other clients', 'Exchange Web Services', 'Exchange Online PowerShell', 'Autodiscover',
            'AutoDiscover', 'Offline Address Book'
        )
    }

    process {
        $since = $now.AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $uri = "/auditLogs/signIns?`$filter=createdDateTime ge $since&`$top=1000"

        try {
            $signIns = Invoke-GkGraphRequest -Uri $uri -CallerFunction 'Get-GkLegacyAuthSignIn'
        }
        catch {
            Write-Warning "Could not read sign-in logs. This report requires a Microsoft Entra ID P1/P2 license and AuditLog.Read.All. $($_.Exception.Message)"
            return
        }

        foreach ($s in $signIns) {
            $client = [string](Get-GkDictValue $s 'clientAppUsed')
            if ($client -notin $legacyClients) { continue }

            $status    = Get-GkDictValue $s 'status'
            $errorCode = [int](Get-GkDictValue $status 'errorCode')
            $isFailure = ($errorCode -ne 0)
            if ($SuccessfulOnly -and $isFailure) { continue }

            $obj = [ordered]@{
                PSTypeName              = 'PSGraphKit.SignIn'
                CreatedDateTime         = ConvertTo-GkDateTime (Get-GkDictValue $s 'createdDateTime')
                UserPrincipalName       = [string](Get-GkDictValue $s 'userPrincipalName')
                AppDisplayName          = [string](Get-GkDictValue $s 'appDisplayName')
                Status                  = if ($isFailure) { 'Failure' } else { 'Success' }
                ErrorCode               = $errorCode
                FailureReason           = [string](Get-GkDictValue $status 'failureReason')
                ConditionalAccessStatus = [string](Get-GkDictValue $s 'conditionalAccessStatus')
                RiskLevel               = [string](Get-GkDictValue $s 'riskLevelAggregated')
                RiskState               = [string](Get-GkDictValue $s 'riskState')
                IpAddress               = [string](Get-GkDictValue $s 'ipAddress')
                ClientApp               = $client
                Id                      = [string](Get-GkDictValue $s 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
