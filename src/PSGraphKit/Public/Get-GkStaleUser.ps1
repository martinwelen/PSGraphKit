function Get-GkStaleUser {
    <#
    .SYNOPSIS
        Report users with no sign-in activity for a threshold number of days, flagging disabled
        and guest accounts.

    .DESCRIPTION
        Reads GET /users with the signInActivity property and computes staleness from the most
        recent interactive OR non-interactive sign-in. Users who have never signed in are treated
        as stale. Each result is flagged for account state (AccountEnabled) and guest status.

        Reading signInActivity requires a Microsoft Entra ID P1 or P2 license and the
        AuditLog.Read.All permission. When the tenant lacks the license, Graph returns no
        signInActivity data; every user then appears as "never signed in" and a warning is
        emitted so the result is not misread. (Degrade mode: warn and continue.)

        Notes on the sign-in timestamps (per Microsoft Graph):
          * LastSignIn            = last interactive sign-in (success or failure).
          * LastNonInteractiveSignIn = last non-interactive sign-in.
          * LastSuccessfulSignIn  = last successful sign-in; only populated from 2023-12-01 and
            not backfilled, so it is reported but not used as the primary staleness signal.
        LastActivity is the most recent of the interactive and non-interactive timestamps.

    .PARAMETER InactiveDays
        Staleness threshold in days (default 90). A user is stale when their last sign-in is at
        least this many days ago, or when they have never signed in.

    .PARAMETER UserType
        Limit to 'Member', 'Guest', or 'All' (default). A non-All value is applied server-side via a
        userType filter (which combines fine with the signInActivity select).

    .PARAMETER IncludeAll
        Return every user with the computed staleness fields, not just the stale ones.

    .PARAMETER AsReport
        Add export-friendly context columns (StaleThresholdDays, ReportGeneratedUtc) for clean
        Export-Csv / Export-Excel output.

    .EXAMPLE
        Get-GkStaleUser -InactiveDays 120

        Users with no sign-in in the last 120 days (including never-signed-in), flagged.

    .EXAMPLE
        Get-GkStaleUser -UserType Guest -InactiveDays 60 |
            Where-Object AccountEnabled |
            Sort-Object InactiveDays -Descending

        Enabled guest accounts stale for 60+ days, most inactive first.

    .EXAMPLE
        Get-GkStaleUser -InactiveDays 90 -AsReport |
            Export-Csv .\stale-users.csv -NoTypeInformation

        Export a stale-user report with threshold/timestamp context columns.

    .OUTPUTS
        PSGraphKit.StaleUser
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.StaleUser')]
    param(
        [ValidateRange(1, 3650)]
        [int] $InactiveDays = 90,

        [ValidateSet('All', 'Member', 'Guest')]
        [string] $UserType = 'All',

        [switch] $IncludeAll,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkStaleUser' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $select = 'id,displayName,userPrincipalName,userType,accountEnabled,signInActivity'
        # userType filters server-side (Get-GkGuestInventory proves it combines with the signInActivity
        # select), so a targeted -UserType doesn't download the whole user population to discard most of it.
        $filter = if ($UserType -ne 'All') { "&`$filter=userType eq '$UserType'" } else { '' }
        $uri = "/users?`$select=$select$filter&`$top=500"

        $users = Invoke-GkGraphRequest -Uri $uri -CallerFunction 'Get-GkStaleUser'

        $sawAnySignInActivity = $false

        foreach ($u in $users) {
            $uType = [string](Get-GkDictValue $u 'userType')
            if ($UserType -ne 'All' -and $uType -ne $UserType) { continue }

            $activity          = Get-GkDictValue $u 'signInActivity'
            $lastInteractive   = ConvertTo-GkDateTime (Get-GkDictValue $activity 'lastSignInDateTime')
            $lastNonInteractive = ConvertTo-GkDateTime (Get-GkDictValue $activity 'lastNonInteractiveSignInDateTime')
            $lastSuccessful    = ConvertTo-GkDateTime (Get-GkDictValue $activity 'lastSuccessfulSignInDateTime')

            if ($null -ne $activity) { $sawAnySignInActivity = $true }

            # Most recent of interactive / non-interactive sign-in.
            $lastActivity = $null
            foreach ($d in @($lastInteractive, $lastNonInteractive)) {
                if ($null -ne $d -and ($null -eq $lastActivity -or $d -gt $lastActivity)) { $lastActivity = $d }
            }

            $neverSignedIn = ($null -eq $lastActivity)
            $inactive      = if ($neverSignedIn) { $null } else { [int][math]::Floor(($now - $lastActivity).TotalDays) }
            $isStale       = $neverSignedIn -or ($inactive -ge $InactiveDays)

            if (-not $IncludeAll -and -not $isStale) { continue }

            $obj = [ordered]@{
                PSTypeName               = 'PSGraphKit.StaleUser'
                DisplayName              = [string](Get-GkDictValue $u 'displayName')
                UserPrincipalName        = [string](Get-GkDictValue $u 'userPrincipalName')
                UserType                 = $uType
                AccountEnabled           = [bool](Get-GkDictValue $u 'accountEnabled')
                IsGuest                  = ($uType -eq 'Guest')
                LastActivity             = $lastActivity
                InactiveDays             = $inactive
                NeverSignedIn            = $neverSignedIn
                IsStale                  = $isStale
                LastSignIn               = $lastInteractive
                LastNonInteractiveSignIn = $lastNonInteractive
                LastSuccessfulSignIn     = $lastSuccessful
                Id                       = [string](Get-GkDictValue $u 'id')
            }
            if ($AsReport) {
                $obj['StaleThresholdDays'] = $InactiveDays
                $obj['ReportGeneratedUtc'] = $now
            }
            [pscustomobject]$obj
        }

        if (-not $sawAnySignInActivity -and @($users).Count -gt 0) {
            Write-Warning "No signInActivity data was returned for any user. Reading signInActivity requires a Microsoft Entra ID P1/P2 license and the AuditLog.Read.All scope; without it, all users appear as never-signed-in. Results may be incomplete."
        }
    }
}
