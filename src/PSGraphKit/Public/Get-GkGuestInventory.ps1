function Get-GkGuestInventory {
    <#
    .SYNOPSIS
        Inventory guest (external) accounts with their sponsor, invitation state, last sign-in,
        and inactivity/age in days.

    .DESCRIPTION
        Lists users where userType eq 'Guest' (GET /users) and, for each, reports the invitation
        state (externalUserState), when it last changed, the account age from createdDateTime, and
        the inactivity age derived from signInActivity. By default it also resolves each guest's
        sponsor(s) via GET /users/{id}/sponsors — one call per guest; use -SkipSponsor to skip that
        on large tenants.

        Sponsor reads depend on the signed-in admin's directory role in delegated sessions; if a
        sponsor lookup is denied, the guest is still returned (Sponsors empty) and a single warning
        is emitted afterward (degrade mode: warn and continue).

        Reading signInActivity requires Entra ID P1/P2 + AuditLog.Read.All; without it, guests
        appear as never-signed-in.

    .PARAMETER InactiveDays
        Threshold in days used to set the IsStale flag (default 90). Never-signed-in guests are stale.

    .PARAMETER StaleOnly
        Return only guests flagged stale (inactive >= InactiveDays, or never signed in).

    .PARAMETER SkipSponsor
        Do not resolve sponsors (skips the per-guest /sponsors call). Sponsors will be empty.

    .PARAMETER AsReport
        Flatten Sponsors to a single '; '-joined string and add ReportGeneratedUtc for clean export.

    .EXAMPLE
        Get-GkGuestInventory

        All guests with sponsor, invitation state, age, and inactivity.

    .EXAMPLE
        Get-GkGuestInventory -StaleOnly -InactiveDays 180 |
            Sort-Object InactiveDays -Descending

        Guests inactive for 180+ days (or never signed in), most inactive first.

    .EXAMPLE
        Get-GkGuestInventory -SkipSponsor -AsReport |
            Export-Csv .\guests.csv -NoTypeInformation

        Fast guest export (no sponsor lookups), sponsors column flattened for CSV.

    .OUTPUTS
        PSGraphKit.GuestInventory
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.GuestInventory')]
    param(
        [ValidateRange(1, 3650)]
        [int] $InactiveDays = 90,

        [switch] $StaleOnly,

        [switch] $SkipSponsor,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkGuestInventory' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $select = 'id,displayName,userPrincipalName,mail,userType,accountEnabled,externalUserState,externalUserStateChangeDateTime,createdDateTime,signInActivity'
        $uri = "/users?`$filter=userType eq 'Guest'&`$select=$select&`$top=500"

        $guests = Invoke-GkGraphRequest -Uri $uri -CallerFunction 'Get-GkGuestInventory'
        $sponsorFailures = 0

        foreach ($g in $guests) {
            $id = [string](Get-GkDictValue $g 'id')

            $activity           = Get-GkDictValue $g 'signInActivity'
            $lastInteractive    = ConvertTo-GkDateTime (Get-GkDictValue $activity 'lastSignInDateTime')
            $lastNonInteractive = ConvertTo-GkDateTime (Get-GkDictValue $activity 'lastNonInteractiveSignInDateTime')

            $lastActivity = $null
            foreach ($d in @($lastInteractive, $lastNonInteractive)) {
                if ($null -ne $d -and ($null -eq $lastActivity -or $d -gt $lastActivity)) { $lastActivity = $d }
            }
            $neverSignedIn = ($null -eq $lastActivity)
            $inactive      = if ($neverSignedIn) { $null } else { [int][math]::Floor(($now - $lastActivity).TotalDays) }
            $isStale       = $neverSignedIn -or ($inactive -ge $InactiveDays)

            if ($StaleOnly -and -not $isStale) { continue }

            $created  = ConvertTo-GkDateTime (Get-GkDictValue $g 'createdDateTime')
            $ageDays  = if ($null -ne $created) { [int][math]::Floor(($now - $created).TotalDays) } else { $null }

            # Sponsors (one call per guest unless skipped).
            $sponsorNames = @()
            if (-not $SkipSponsor -and $id) {
                try {
                    $sponsors = Invoke-GkGraphRequest -Uri "/users/$id/sponsors?`$select=id,displayName" -CallerFunction 'Get-GkGuestInventory'
                    $sponsorNames = @(
                        $sponsors | ForEach-Object { [string](Get-GkDictValue $_ 'displayName') } | Where-Object { $_ }
                    )
                }
                catch {
                    $sponsorFailures++
                    Write-Verbose "PSGraphKit: sponsor lookup failed for $id : $($_.Exception.Message)"
                }
            }

            $obj = [ordered]@{
                PSTypeName             = 'PSGraphKit.GuestInventory'
                DisplayName            = [string](Get-GkDictValue $g 'displayName')
                UserPrincipalName      = [string](Get-GkDictValue $g 'userPrincipalName')
                Mail                   = [string](Get-GkDictValue $g 'mail')
                AccountEnabled         = [bool](Get-GkDictValue $g 'accountEnabled')
                InvitationState        = [string](Get-GkDictValue $g 'externalUserState')
                InvitationStateChanged = ConvertTo-GkDateTime (Get-GkDictValue $g 'externalUserStateChangeDateTime')
                Created                = $created
                GuestAgeDays           = $ageDays
                LastActivity           = $lastActivity
                InactiveDays           = $inactive
                NeverSignedIn          = $neverSignedIn
                IsStale                = $isStale
                Sponsors               = if ($AsReport) { $sponsorNames -join '; ' } else { , $sponsorNames }
                SponsorCount           = $sponsorNames.Count
                Id                     = $id
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }

        if ($sponsorFailures -gt 0) {
            Write-Warning "Sponsor lookup was denied for $sponsorFailures guest(s). In a delegated session, reading /sponsors needs a directory role granting microsoft.directory/users/sponsors/read (e.g. Directory Readers, Guest Inviter, User Administrator). Those guests are returned with no sponsors."
        }
    }
}
