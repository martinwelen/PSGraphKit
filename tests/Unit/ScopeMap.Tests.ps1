Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

# Pins the scope map to what was verified against Microsoft Learn (see DESIGN.md section 7).
# These are not tests of behaviour — they are a tripwire. When Microsoft changes a permission, or
# someone edits the map by hand, the diff shows up here instead of as a 403 in a customer tenant.
InModuleScope PSGraphKit {

    Describe 'Scope map — structure' {

        BeforeAll {
            $script:Map = $script:GkScopeMap
            # Only the public surface: InModuleScope also sees the private helpers.
            $script:Exported = @((Get-Module PSGraphKit).ExportedFunctions.Keys)
        }

        It 'has an entry for every exported cmdlet' {
            $missing = @($script:Exported | Where-Object { -not $script:Map.ContainsKey($_) })
            $missing | Should -BeNullOrEmpty -Because "every public cmdlet must declare its scopes; missing: $($missing -join ', ')"
        }

        It 'has no entry for a cmdlet that does not exist' {
            # Variant keys ('<cmdlet>:<variant>') resolve to their base cmdlet.
            $orphans = @($script:Map.Keys | Where-Object { $script:Exported -notcontains ($_ -split ':')[0] })
            $orphans | Should -BeNullOrEmpty -Because "stale scope entries mislead Connect-GkGraph -AllCommands; orphans: $($orphans -join ', ')"
        }

        It 'declares every capability group with a purpose and at least one scope' {
            foreach ($key in $script:Map.Keys) {
                foreach ($group in @($script:Map[$key].Groups)) {
                    $group.For | Should -Not -BeNullOrEmpty -Because "$key has a group with no 'For' description"
                    @($group.Any).Count | Should -BeGreaterThan 0 -Because "$key group '$($group.For)' offers no scope"
                }
            }
        }

        It 'names scopes in a plausible Graph form' {
            foreach ($key in $script:Map.Keys) {
                foreach ($group in @($script:Map[$key].Groups)) {
                    foreach ($scope in @($group.Any)) {
                        $scope | Should -Match '^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z][A-Za-z0-9]*)+$' -Because "'$scope' in $key does not look like a Graph permission"
                    }
                }
            }
        }

        It 'does not lead a capability group with a directory-wide scope' {
            # Get-GkConnectScopeHint takes the first entry, so ordering is load-bearing: it is what
            # Connect-GkGraph -ForCommand requests and what the error message recommends. Leading
            # with Directory.*.All would have every cmdlet ask for the whole directory.
            $broadest = 'Directory.ReadWrite.All', 'Directory.Read.All'

            # Exception: where Graph's own least-privileged option is a WRITE scope, a read-only
            # cmdlet leads with the directory read instead — asking a reporting cmdlet to request
            # write access is worse than asking for a broad read. See DESIGN.md section 7.
            $writeOnlyAlternative = @{
                'Get-GkUserAccessReport' = @('read app role assignments')   # least is AppRoleAssignment.ReadWrite.All
            }

            foreach ($key in $script:Map.Keys) {
                foreach ($group in @($script:Map[$key].Groups)) {
                    $any = @($group.Any)
                    if ($any.Count -lt 2) { continue }
                    if ($writeOnlyAlternative[$key] -contains $group.For) { continue }
                    $any[0] | Should -Not -BeIn $broadest -Because "$key group '$($group.For)' leads with a directory-wide scope"
                }
            }
        }
    }

    Describe 'Scope map — verified declarations' {

        # Each case below was confirmed against the permission table on the cmdlet's Learn page.
        # Update only alongside a documentation change, and record it in DESIGN.md section 7.
        $cases = @(
            @{ Cmdlet = 'Disable-GkStaleUser';          Group = 'block user sign-in (accountEnabled)'; Expected = 'User.EnableDisableAccount.All,User.ReadUpdate.All,User.ReadWrite.All,Directory.ReadWrite.All' }
            @{ Cmdlet = 'Disable-GkStaleUser';          Group = 'read the target user';                Expected = 'User.Read.All,User.ReadUpdate.All,User.ReadWrite.All,Directory.Read.All,Directory.ReadWrite.All' }
            @{ Cmdlet = 'Remove-GkStaleGuest';          Group = 'disable a guest (accountEnabled)';    Expected = 'User.EnableDisableAccount.All,User.ReadUpdate.All,User.ReadWrite.All,Directory.ReadWrite.All' }
            @{ Cmdlet = 'Remove-GkStaleGuest:Delete';   Group = 'delete a user (30-day soft-delete)';  Expected = 'User.ReadWrite.All,Directory.ReadWrite.All' }
            @{ Cmdlet = 'Get-GkCustomRole';             Group = 'read role definitions';               Expected = 'RoleManagement.Read.Directory,Directory.Read.All' }
            @{ Cmdlet = 'Get-GkAdminRoleAssignment';    Group = 'read role assignments and PIM schedules'; Expected = 'RoleManagement.Read.Directory,RoleManagement.Read.All,Directory.Read.All' }
            @{ Cmdlet = 'Get-GkRoleAssignableGroup';    Group = 'read groups and owners';              Expected = 'GroupMember.Read.All,Group.Read.All,Directory.Read.All' }
            @{ Cmdlet = 'Get-GkGroupReport';            Group = 'read groups';                         Expected = 'Group.Read.All,Directory.Read.All,GroupMember.Read.All' }
            @{ Cmdlet = 'Get-GkUserMfaStatus';          Group = 'read authentication method registration report'; Expected = 'AuditLog.Read.All' }
            @{ Cmdlet = 'Remove-GkAdminRoleAssignment'; Group = 'remove role assignments (active and PIM)'; Expected = 'RoleManagement.ReadWrite.Directory' }
        )

        It '<Cmdlet> / <Group>' -TestCases $cases {
            param($Cmdlet, $Group, $Expected)
            $entry = $script:GkScopeMap[$Cmdlet]
            $entry | Should -Not -BeNullOrEmpty
            $g = @($entry.Groups | Where-Object For -eq $Group)
            @($g).Count | Should -Be 1 -Because "expected exactly one capability group named '$Group' on $Cmdlet"
            (@($g[0].Any) -join ',') | Should -Be $Expected
        }
    }

    Describe 'Scope map — documented exclusions' {

        # Scopes deliberately NOT accepted. If someone adds one of these, they are reintroducing a
        # defect the audit removed; DESIGN.md section 7 explains each.
        It 'does not accept RoleManagement.Read.All for Get-GkCustomRole' {
            # The directory provider's table for GET /roleManagement/directory/roleDefinitions omits
            # it, so it would pass pre-flight and then take a 403.
            @($script:GkScopeMap['Get-GkCustomRole'].Groups.Any) | Should -Not -Contain 'RoleManagement.Read.All'
        }

        It 'does not accept a write scope for the read-only group cmdlets' {
            foreach ($c in 'Get-GkGroupReport', 'Get-GkRoleAssignableGroup') {
                @($script:GkScopeMap[$c].Groups.Any) | Should -Not -Contain 'Group-NestingSupport.ReadWrite.All' -Because "$c is read-only"
            }
        }

        It 'does not accept User.Read for Get-GkUserAccessReport' {
            # User.Read grants the signed-in user's own profile; the cmdlet reads arbitrary users.
            @($script:GkScopeMap['Get-GkUserAccessReport'].Groups.Any) | Should -Not -Contain 'User.Read'
        }
    }
}
