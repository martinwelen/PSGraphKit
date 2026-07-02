Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkGuestInventory' {

        BeforeAll {
            $guestsPath   = Join-Path $PSScriptRoot '..' 'fixtures' 'guests.json'
            $sponsorsPath = Join-Path $PSScriptRoot '..' 'fixtures' 'sponsors.json'
            $script:GuestValue    = (Get-Content $guestsPath   -Raw | ConvertFrom-Json -AsHashtable)['value']
            $script:SponsorValue  = (Get-Content $sponsorsPath -Raw | ConvertFrom-Json -AsHashtable)['value']
        }

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*/sponsors*') { $script:SponsorValue } else { $script:GuestValue }
            }
        }

        It 'emits typed objects and validates the connection' {
            $r = Get-GkGuestInventory
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.GuestInventory'
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Get-GkGuestInventory' }
        }

        It 'maps invitation state and computes guest age' {
            $gita = Get-GkGuestInventory | Where-Object DisplayName -eq 'Gita Guest'
            $gita.InvitationState | Should -Be 'Accepted'
            $gita.GuestAgeDays    | Should -BeGreaterThan 0
            $gita.Created         | Should -Be ([datetime]::new(2023, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc))
        }

        It 'treats a pending guest with no sign-in as never signed in' {
            $pat = Get-GkGuestInventory | Where-Object DisplayName -eq 'Pending Pat'
            $pat.NeverSignedIn | Should -BeTrue
            $pat.InvitationState | Should -Be 'PendingAcceptance'
        }

        It 'resolves sponsors per guest by default' {
            $gita = Get-GkGuestInventory | Where-Object DisplayName -eq 'Gita Guest'
            $gita.Sponsors      | Should -Contain 'Sponsor Sam'
            $gita.SponsorCount  | Should -Be 1
            # one /sponsors call per guest (2 guests)
            Should -Invoke Invoke-GkGraphRequest -Times 2 -Exactly -ParameterFilter { $Uri -like '*/sponsors*' }
        }

        It '-SkipSponsor makes no /sponsors calls' {
            Get-GkGuestInventory -SkipSponsor | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*/sponsors*' }
        }

        It '-StaleOnly filters by inactivity threshold' {
            # Both fixture guests are years-old / never, so both are stale at 90 days.
            (Get-GkGuestInventory -StaleOnly -InactiveDays 90).Count | Should -Be 2
            # With an impossibly large threshold, the signed-in guest is no longer stale;
            # the never-signed-in guest remains stale.
            $r = Get-GkGuestInventory -StaleOnly -InactiveDays 3650
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Pending Pat'
        }

        It '-AsReport flattens Sponsors to a string and adds a timestamp' {
            $gita = Get-GkGuestInventory -AsReport | Where-Object DisplayName -eq 'Gita Guest'
            $gita.Sponsors            | Should -BeOfType ([string])
            $gita.Sponsors            | Should -Be 'Sponsor Sam'
            $gita.ReportGeneratedUtc  | Should -BeOfType ([datetime])
        }

        It 'warns and continues when a sponsor lookup is denied' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*/sponsors*') { throw 'denied' } else { $script:GuestValue }
            }
            $warnings = @()
            $r = Get-GkGuestInventory -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Count | Should -Be 2
            ($warnings -join ' ') | Should -Match 'sponsor'
        }
    }
}
