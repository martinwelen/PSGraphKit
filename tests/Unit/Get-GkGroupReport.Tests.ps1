Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkGroupReport' {

        BeforeAll {
            $path = Join-Path $PSScriptRoot '..' 'fixtures' 'groups.json'
            $script:GroupValue = (Get-Content $path -Raw | ConvertFrom-Json -AsHashtable)['value']
        }

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Group.Read.All', 'GroupMember.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*/members*') { return @{ '@odata.count' = 7; value = @() } }   # $count=true query
                if ($Uri -like '*/owners*') {
                    if ($Uri -like '*m365-1*') { return @() }                    # ownerless
                    return @(@{ id = 'o1'; displayName = 'Olga Owner' })
                }
                return $script:GroupValue                                        # /groups list
            }
        }

        It 'classifies group types correctly' {
            $r = Get-GkGroupReport
            ($r | Where-Object Id -eq 'm365-1').GroupType | Should -Be 'Microsoft365'
            ($r | Where-Object Id -eq 'sec-1').GroupType  | Should -Be 'Security'
            ($r | Where-Object Id -eq 'dist-1').GroupType | Should -Be 'Distribution'
            $dyn = $r | Where-Object Id -eq 'dyn-1'
            $dyn.GroupType | Should -Be 'Security'
            $dyn.IsDynamic | Should -BeTrue
        }

        It 'fetches membership count per group from @odata.count' {
            $r = Get-GkGroupReport
            $r[0].MemberCount | Should -Be 7
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.GroupReport'
            # must use the JSON $count=true query, not the text/plain /$count endpoint
            Should -Invoke Invoke-GkGraphRequest -ParameterFilter { $Uri -like '*/members?*$count=true*' }
            Should -Not -Invoke Invoke-GkGraphRequest -ParameterFilter { $Uri -like '*/members/$count*' }
        }

        It 'warns (does not silently null) when the membership count fails' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*/members*') { throw 'Non-Json response' }
                if ($Uri -like '*/owners*')  { return @() }
                return $script:GroupValue
            }
            $warnings = @()
            $r = Get-GkGroupReport -WarningVariable warnings -WarningAction SilentlyContinue
            $r[0].MemberCount | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'Membership count'
        }

        It 'flags an ownerless group and lists owners otherwise' {
            $r = Get-GkGroupReport
            ($r | Where-Object Id -eq 'm365-1').IsOwnerless | Should -BeTrue
            $sec = $r | Where-Object Id -eq 'sec-1'
            $sec.IsOwnerless | Should -BeFalse
            $sec.Owners      | Should -Contain 'Olga Owner'
        }

        It '-SkipMemberCount avoids the members/$count call' {
            $r = Get-GkGroupReport -SkipMemberCount
            $r[0].MemberCount | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*/members*' }
        }

        It '-OwnerlessOnly returns only ownerless groups' {
            $r = Get-GkGroupReport -OwnerlessOnly
            $r.Count | Should -Be 1
            $r[0].Id | Should -Be 'm365-1'
        }

        It '-GroupType filters client-side' {
            $r = Get-GkGroupReport -GroupType Distribution
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Announcements (Distribution)'
        }

        It '-AsReport flattens owners and adds a timestamp' {
            $sec = Get-GkGroupReport -AsReport | Where-Object Id -eq 'sec-1'
            $sec.Owners           | Should -Be 'Olga Owner'
            $sec.ReportGeneratedUtc | Should -BeOfType ([datetime])
        }
    }
}
