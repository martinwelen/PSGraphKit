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
