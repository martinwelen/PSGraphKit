function Get-GkSignInReport {
    <#
    .SYNOPSIS
        Report Entra sign-ins over a recent window, with risk and Conditional Access status.

    .DESCRIPTION
        Reads GET /auditLogs/signIns filtered to the last -Days (a date filter is required by the
        API in practice). Returns interactive sign-ins with status, failure reason, risk, CA status,
        IP, and client app.

        Requires a Microsoft Entra ID P1 or P2 license and the AuditLog.Read.All scope (add
        Policy.Read.All to populate applied CA policy detail). Risk fields require P2. Standard
        sign-in log retention is ~7 days (free) / ~30 days (P1/P2). Unavailable data warns and
        returns nothing rather than failing.

    .PARAMETER Days
        Look-back window in days (default 7).

    .PARAMETER First
        Return only the N most-recent sign-ins in the window (Graph returns them newest-first),
        stopping pagination early. Applied before -FailedOnly/-RiskyOnly, so those refine within the
        N fetched. Use for a fast, bounded look at a high-volume tenant.

    .PARAMETER UserPrincipalName
        Filter to a single user's sign-ins.

    .PARAMETER FailedOnly
        Return only failed sign-ins.

    .PARAMETER RiskyOnly
        Return only sign-ins with a non-none aggregated risk level (P2).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkSignInReport -Days 3 -FailedOnly | Group-Object UserPrincipalName | Sort-Object Count -Descending

        Failed sign-ins in the last 3 days, grouped by user.

    .EXAMPLE
        Get-GkSignInReport -RiskyOnly -Days 7

        Risky sign-ins in the last week.

    .EXAMPLE
        Get-GkSignInReport -UserPrincipalName ada@contoso.com -Days 1

        One user's sign-ins in the last day.

    .OUTPUTS
        PSGraphKit.SignIn
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.SignIn')]
    param(
        [ValidateRange(1, 30)]
        [int] $Days = 7,

        [ValidateRange(1, 500000)]
        [int] $First,

        [string] $UserPrincipalName,

        [switch] $FailedOnly,

        [switch] $RiskyOnly,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkSignInReport' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $since = $now.AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $filters = @("createdDateTime ge $since")
        if ($UserPrincipalName) { $filters += "userPrincipalName eq '$UserPrincipalName'" }
        $uri = '/auditLogs/signIns?$filter=' + ($filters -join ' and ') + '&$top=1000'

        try {
            $signIns = Invoke-GkGraphRequest -Uri $uri -MaxResult $First -CallerFunction 'Get-GkSignInReport'
        }
        catch {
            Write-Warning "Could not read sign-in logs. This report requires a Microsoft Entra ID P1/P2 license and AuditLog.Read.All. $($_.Exception.Message)"
            return
        }

        foreach ($s in $signIns) {
            $status    = Get-GkDictValue $s 'status'
            $errorCode = [int](Get-GkDictValue $status 'errorCode')
            $isFailure = ($errorCode -ne 0)
            $risk      = [string](Get-GkDictValue $s 'riskLevelAggregated')

            if ($FailedOnly -and -not $isFailure) { continue }
            if ($RiskyOnly -and ($risk -in @('', 'none', 'hidden'))) { continue }

            $obj = [ordered]@{
                PSTypeName              = 'PSGraphKit.SignIn'
                CreatedDateTime         = ConvertTo-GkDateTime (Get-GkDictValue $s 'createdDateTime')
                UserPrincipalName       = [string](Get-GkDictValue $s 'userPrincipalName')
                AppDisplayName          = [string](Get-GkDictValue $s 'appDisplayName')
                Status                  = if ($isFailure) { 'Failure' } else { 'Success' }
                ErrorCode               = $errorCode
                FailureReason           = [string](Get-GkDictValue $status 'failureReason')
                ConditionalAccessStatus = [string](Get-GkDictValue $s 'conditionalAccessStatus')
                RiskLevel               = $risk
                RiskState               = [string](Get-GkDictValue $s 'riskState')
                IpAddress               = [string](Get-GkDictValue $s 'ipAddress')
                ClientApp               = [string](Get-GkDictValue $s 'clientAppUsed')
                Id                      = [string](Get-GkDictValue $s 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
