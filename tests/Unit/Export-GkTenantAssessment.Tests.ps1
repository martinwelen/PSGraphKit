Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Export-GkTenantAssessment' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; TenantId = 't1'; Account = 'admin@contoso.com'; Scopes = @() } }
            Mock Get-GkStaleUser { @([pscustomobject]@{ DisplayName = 'Ada Admin'; UserPrincipalName = 'ada@contoso.com'; IsStale = $true }) }
            Mock Get-GkLicenseOverview { @([pscustomobject]@{ SkuPartNumber = 'ENTERPRISEPACK'; Available = 5 }) }
        }

        It 'writes a self-contained HTML file with the requested sections and data' {
            $out = Join-Path $TestDrive 'a.html'
            Export-GkTenantAssessment -Path $out -Include StaleUsers, Licenses
            Test-Path $out | Should -BeTrue
            $html = Get-Content $out -Raw
            $html | Should -Match '<h1>'
            $html | Should -Match '<style>'          # inline CSS (self-contained)
            $html | Should -Match 'Stale Users'
            $html | Should -Match 'License Overview'
            $html | Should -Match 'Ada Admin'
        }

        It 'states which tenant it describes, when, and by whom' {
            # This document gets handed to a client. Without provenance it is an unattributable
            # table of someone's directory, and nothing in the file says whose or how old.
            $out = Join-Path $TestDrive 'meta.html'
            Export-GkTenantAssessment -Path $out -Include StaleUsers
            $html = Get-Content $out -Raw
            $html | Should -Match 'Tenant t1'
            $html | Should -Match 'admin@contoso\.com'
            $html | Should -Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}Z'
        }

        It 'escapes tenant data instead of rendering it as markup' {
            # Display names are attacker-influencable in a tenant that accepts self-service or guest
            # sign-up, and this output is opened in a browser by someone who trusts it.
            Mock Get-GkStaleUser {
                @([pscustomobject]@{
                    DisplayName       = '<script>alert(1)</script>'
                    UserPrincipalName = 'evil@contoso.com'
                })
            }
            $out = Join-Path $TestDrive 'xss.html'
            Export-GkTenantAssessment -Path $out -Include StaleUsers
            $html = Get-Content $out -Raw
            $html | Should -Not -Match '<script>alert'
            $html | Should -Match '&lt;script&gt;'
        }

        It 'notes a failing section but still completes the document' {
            Mock Get-GkStaleUser { throw 'missing scope AuditLog.Read.All' }
            $out = Join-Path $TestDrive 'b.html'
            Export-GkTenantAssessment -Path $out -Include StaleUsers, Licenses -WarningAction SilentlyContinue
            $html = Get-Content $out -Raw
            $html | Should -Match 'Unavailable'
            $html | Should -Match 'License Overview'   # the other section still rendered
        }

        It 'writes a CSV per section with -CsvFolder' {
            $out = Join-Path $TestDrive 'c.html'
            $csv = Join-Path $TestDrive 'csv'
            Export-GkTenantAssessment -Path $out -Include Licenses -CsvFolder $csv
            Test-Path (Join-Path $csv 'Licenses.csv') | Should -BeTrue
        }

        It 'returns the file with -PassThru' {
            $out = Join-Path $TestDrive 'd.html'
            $f = Export-GkTenantAssessment -Path $out -Include Licenses -PassThru
            $f.FullName | Should -Be (Get-Item $out).FullName
        }
    }
}
