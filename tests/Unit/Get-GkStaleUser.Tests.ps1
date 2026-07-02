Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkStaleUser' {

        BeforeAll {
            $fixturePath = Join-Path $PSScriptRoot '..' 'fixtures' 'users-signinactivity.json'
            $script:FixtureValue = (Get-Content $fixturePath -Raw | ConvertFrom-Json -AsHashtable)['value']
        }

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('AuditLog.Read.All', 'User.Read.All') } }
            Mock Invoke-GkGraphRequest { $script:FixtureValue }
        }

        It 'validates the connection before querying' {
            Get-GkStaleUser | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Get-GkStaleUser' }
        }

        It 'emits typed PSGraphKit.StaleUser objects' {
            $r = Get-GkStaleUser
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.StaleUser'
        }

        It 'returns all fixture users as stale (all last sign-ins are years old)' {
            $r = Get-GkStaleUser -InactiveDays 90
            $r.Count | Should -Be 4
            ($r | Where-Object IsStale).Count | Should -Be 4
        }

        It 'flags guest and disabled accounts' {
            $r = Get-GkStaleUser
            ($r | Where-Object UserPrincipalName -like 'bob*').IsGuest        | Should -BeTrue
            ($r | Where-Object DisplayName -eq 'Carol Chen').AccountEnabled   | Should -BeFalse
        }

        It 'treats a user with no signInActivity as never signed in' {
            $dave = (Get-GkStaleUser | Where-Object DisplayName -eq 'Dave Dahl')
            $dave.NeverSignedIn | Should -BeTrue
            $dave.InactiveDays  | Should -BeNullOrEmpty
            $dave.LastActivity  | Should -BeNullOrEmpty
        }

        It 'uses the most recent of interactive and non-interactive sign-in for LastActivity' {
            $alice = (Get-GkStaleUser | Where-Object DisplayName -eq 'Alice Adams')
            # non-interactive (2021-02-01) is later than interactive (2021-01-15)
            $alice.LastActivity | Should -Be ([datetime]::new(2021, 2, 1, 9, 0, 0, [System.DateTimeKind]::Utc))
            $alice.InactiveDays | Should -BeGreaterThan 0
        }

        It 'filters to guests only with -UserType Guest' {
            $r = Get-GkStaleUser -UserType Guest
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Bob Bianchi'
        }

        It 'excludes non-stale users unless -IncludeAll (recent sign-in)' {
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'a'; displayName = 'Recent Rita'; userPrincipalName = 'rita@contoso.com'; userType = 'Member'; accountEnabled = $true
                       signInActivity = @{ lastSignInDateTime = ([datetime]::UtcNow.AddDays(-3).ToString('o')) } }
                    @{ id = 'b'; displayName = 'Stale Sam'; userPrincipalName = 'sam@contoso.com'; userType = 'Member'; accountEnabled = $true
                       signInActivity = @{ lastSignInDateTime = ([datetime]::UtcNow.AddDays(-200).ToString('o')) } }
                )
            }
            $default = Get-GkStaleUser -InactiveDays 90
            $default.Count | Should -Be 1
            $default[0].DisplayName | Should -Be 'Stale Sam'

            $all = Get-GkStaleUser -InactiveDays 90 -IncludeAll
            $all.Count | Should -Be 2
            ($all | Where-Object DisplayName -eq 'Recent Rita').IsStale | Should -BeFalse
        }

        It 'adds report context columns with -AsReport' {
            $r = Get-GkStaleUser -AsReport
            $r[0].StaleThresholdDays | Should -Be 90
            $r[0].ReportGeneratedUtc | Should -BeOfType ([datetime])
        }

        It 'warns when no signInActivity is present for any user (P1/P2 missing)' {
            Mock Invoke-GkGraphRequest {
                @( @{ id = 'x'; displayName = 'No Data'; userPrincipalName = 'x@contoso.com'; userType = 'Member'; accountEnabled = $true } )
            }
            $warnings = @()
            Get-GkStaleUser -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
            ($warnings -join ' ') | Should -Match 'P1/P2'
        }
    }
}
