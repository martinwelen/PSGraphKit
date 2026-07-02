Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkUserAccessReport' {

        BeforeAll {
            $fx = Join-Path $PSScriptRoot '..' 'fixtures'
            $script:UserObj     = (Get-Content (Join-Path $fx 'user-access-user.json')               -Raw | ConvertFrom-Json -AsHashtable)
            $script:MemberOf    = (Get-Content (Join-Path $fx 'user-access-memberof.json')            -Raw | ConvertFrom-Json -AsHashtable)['value']
            $script:AppRoles    = (Get-Content (Join-Path $fx 'user-access-approleassignments.json')  -Raw | ConvertFrom-Json -AsHashtable)['value']
            $script:LicDetails  = (Get-Content (Join-Path $fx 'user-access-licensedetails.json')      -Raw | ConvertFrom-Json -AsHashtable)['value']
        }

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Directory.Read.All', 'LicenseAssignment.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*transitiveMemberOf*')  { return $script:MemberOf }
                if ($Uri -like '*appRoleAssignments*')  { return $script:AppRoles }
                if ($Uri -like '*licenseDetails*')      { return $script:LicDetails }
                return $script:UserObj    # the /users/{id} identity read (-Raw)
            }
        }

        It 'emits one typed object per user with identity fields' {
            $r = Get-GkUserAccessReport -UserId 'ada@contoso.com'
            $r.PSTypeNames[0]     | Should -Be 'PSGraphKit.UserAccessReport'
            $r.UserPrincipalName  | Should -Be 'ada@contoso.com'
            $r.AccountEnabled     | Should -BeTrue
        }

        It 'does not put @odata.type in the transitiveMemberOf $select (Graph rejects it)' {
            $seen = [System.Collections.Generic.List[string]]::new()
            Mock Invoke-GkGraphRequest {
                $seen.Add($Uri)
                if ($Uri -like '*transitiveMemberOf*') { return $script:MemberOf }
                if ($Uri -like '*appRoleAssignments*') { return $script:AppRoles }
                if ($Uri -like '*licenseDetails*')     { return $script:LicDetails }
                return $script:UserObj
            }
            Get-GkUserAccessReport -UserId 'ada@contoso.com' | Out-Null
            ($seen | Where-Object { $_ -like '*transitiveMemberOf*' }) | Should -Not -BeLike '*@odata.type*'
        }

        It 'classifies transitiveMemberOf into groups and roles (ignoring AUs)' {
            $r = Get-GkUserAccessReport -UserId 'ada@contoso.com'
            $r.GroupCount | Should -Be 2
            $r.Groups     | Should -Contain 'Finance Team'
            $r.RoleCount  | Should -Be 1
            $r.DirectoryRoles | Should -Contain 'Global Administrator'
        }

        It 'collects app assignments and licenses' {
            $r = Get-GkUserAccessReport -UserId 'ada@contoso.com'
            $r.AppRoleAssignments | Should -Contain 'Salesforce'
            $r.AppCount           | Should -Be 2
            $r.Licenses           | Should -Contain 'AAD_PREMIUM_P2'
            $r.LicenseCount       | Should -Be 2
        }

        It 'accepts pipeline input for multiple users' {
            $r = 'ada@contoso.com', 'bob@contoso.com' | Get-GkUserAccessReport
            $r.Count | Should -Be 2
        }

        It 'flattens collections and adds a timestamp with -AsReport' {
            $r = Get-GkUserAccessReport -UserId 'ada@contoso.com' -AsReport
            $r.Groups            | Should -Be 'Finance Team; All Staff'
            $r.Licenses          | Should -BeOfType ([string])
            $r.ReportGeneratedUtc | Should -BeOfType ([datetime])
        }

        It 'skips a user that cannot be resolved and warns' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*/users/ghost*') { throw 'Request_ResourceNotFound' }
                if ($Uri -like '*transitiveMemberOf*') { return $script:MemberOf }
                if ($Uri -like '*appRoleAssignments*') { return $script:AppRoles }
                if ($Uri -like '*licenseDetails*') { return $script:LicDetails }
                return $script:UserObj
            }
            $warnings = @()
            $r = 'ghost@contoso.com', 'ada@contoso.com' | Get-GkUserAccessReport -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Count | Should -Be 1
            ($warnings -join ' ') | Should -Match 'ghost'
        }

        It 'percent-encodes a guest UPN so the # is not treated as a URL fragment' {
            $captured = [System.Collections.Generic.List[string]]::new()
            Mock Invoke-GkGraphRequest {
                $captured.Add($Uri)
                if ($Uri -like '*transitiveMemberOf*') { return $script:MemberOf }
                if ($Uri -like '*appRoleAssignments*') { return $script:AppRoles }
                if ($Uri -like '*licenseDetails*')     { return $script:LicDetails }
                return $script:UserObj
            }
            $guestUpn = "bob_partner.com#EXT#@contoso.onmicrosoft.com"
            Get-GkUserAccessReport -UserId $guestUpn | Out-Null

            # every request must carry the encoded id and never a raw '#'
            $captured | Should -Not -BeNullOrEmpty
            foreach ($u in $captured) { $u | Should -Not -BeLike '*#*' }
            ($captured | Where-Object { $_ -like '*%23EXT%23*' }).Count | Should -BeGreaterThan 0
        }

        It 'continues when one facet is denied' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*licenseDetails*')     { throw 'Authorization_RequestDenied' }
                if ($Uri -like '*transitiveMemberOf*') { return $script:MemberOf }
                if ($Uri -like '*appRoleAssignments*') { return $script:AppRoles }
                return $script:UserObj
            }
            $warnings = @()
            $r = Get-GkUserAccessReport -UserId 'ada@contoso.com' -WarningVariable warnings -WarningAction SilentlyContinue
            $r.LicenseCount | Should -Be 0
            $r.GroupCount   | Should -Be 2
            ($warnings -join ' ') | Should -Match 'license'
        }
    }
}
