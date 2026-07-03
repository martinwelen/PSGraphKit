function Get-GkInactiveApp {
    <#
    .SYNOPSIS
        Report enterprise apps / service principals with no recent sign-in activity (decommission
        candidates).

    .DESCRIPTION
        Reads GET /reports/servicePrincipalSignInActivities (beta) and computes each service
        principal's most recent activity across its delegated/application client and resource
        sign-ins. Service principal display names are resolved from /servicePrincipals.

        This report is on the Microsoft Graph BETA endpoint (no v1.0 equivalent) and is global-cloud
        only. Requires AuditLog.Read.All. Unavailable data warns and returns nothing.

    .PARAMETER InactiveDays
        Staleness threshold in days (default 90). An app is stale when its last activity is at least
        this many days ago, or it has none recorded.

    .PARAMETER StaleOnly
        Return only stale apps (default returns all with the computed fields).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkInactiveApp -InactiveDays 180 -StaleOnly | Sort-Object InactiveDays -Descending

        Enterprise apps unused for 180+ days.

    .EXAMPLE
        Get-GkInactiveApp | Where-Object NeverActive

        Apps with no recorded sign-in activity at all.

    .EXAMPLE
        Get-GkInactiveApp -StaleOnly -AsReport | Export-Csv .\inactive-apps.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.InactiveApp
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.InactiveApp')]
    param(
        [ValidateRange(1, 3650)]
        [int] $InactiveDays = 90,

        [switch] $StaleOnly,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkInactiveApp' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        try {
            $activities = Invoke-GkGraphRequest -ApiVersion beta -Uri '/reports/servicePrincipalSignInActivities' -CallerFunction 'Get-GkInactiveApp'
        }
        catch {
            Write-Warning "Could not read service principal sign-in activities (beta report, requires AuditLog.Read.All, global cloud only). $($_.Exception.Message)"
            return
        }

        # appId -> displayName map (one call).
        $nameByAppId = @{}
        foreach ($sp in (Invoke-GkGraphRequest -Uri '/servicePrincipals?$select=appId,displayName&$top=999' -CallerFunction 'Get-GkInactiveApp')) {
            $aid = [string](Get-GkDictValue $sp 'appId')
            if ($aid) { $nameByAppId[$aid] = [string](Get-GkDictValue $sp 'displayName') }
        }

        foreach ($a in $activities) {
            $appId = [string](Get-GkDictValue $a 'appId')
            $last = $null
            foreach ($key in 'delegatedClientSignInActivity', 'delegatedResourceSignInActivity', 'applicationAuthenticationClientSignInActivity', 'applicationAuthenticationResourceSignInActivity') {
                $d = ConvertTo-GkDateTime (Get-GkDictValue (Get-GkDictValue $a $key) 'lastSignInDateTime')
                if ($null -ne $d -and ($null -eq $last -or $d -gt $last)) { $last = $d }
            }

            $never = ($null -eq $last)
            $inactive = if ($never) { $null } else { [int][math]::Floor(($now - $last).TotalDays) }
            $isStale = $never -or ($inactive -ge $InactiveDays)
            if ($StaleOnly -and -not $isStale) { continue }

            $obj = [ordered]@{
                PSTypeName     = 'PSGraphKit.InactiveApp'
                AppDisplayName = if ($nameByAppId.ContainsKey($appId)) { $nameByAppId[$appId] } else { $appId }
                AppId          = $appId
                LastActivity   = $last
                InactiveDays   = $inactive
                NeverActive    = $never
                IsStale        = $isStale
                Id             = [string](Get-GkDictValue $a 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
