Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkCaPolicyReport' {

        BeforeAll {
            $path = Join-Path $PSScriptRoot '..' 'fixtures' 'caPolicies.json'
            $script:CaValue = (Get-Content $path -Raw | ConvertFrom-Json -AsHashtable)['value']
        }

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Policy.Read.All') } }
            Mock Invoke-GkGraphRequest { $script:CaValue }
        }

        It 'emits one typed row per policy with state' {
            $r = Get-GkCaPolicyReport
            $r.Count | Should -Be 3
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.CaPolicy'
        }

        It 'summarizes grant controls (mfa, Block, none)' {
            $r = Get-GkCaPolicyReport
            ($r | Where-Object Id -eq 'ca1').GrantControls | Should -Be 'mfa'
            ($r | Where-Object Id -eq 'ca2').GrantControls | Should -Be 'Block'
            ($r | Where-Object Id -eq 'ca3').GrantControls | Should -Be '(none)'
        }

        It 'summarizes included users and target apps' {
            $ca1 = Get-GkCaPolicyReport | Where-Object Id -eq 'ca1'
            $ca1.IncludedUsers | Should -Be 'All users'
            $ca1.TargetApps    | Should -Be 'All cloud apps'

            $ca3 = Get-GkCaPolicyReport | Where-Object Id -eq 'ca3'
            $ca3.IncludedUsers | Should -Match 'group'
            $ca3.TargetApps    | Should -Be '1 app(s)'
        }

        It 'lists only enabled session controls' {
            $ca3 = Get-GkCaPolicyReport | Where-Object Id -eq 'ca3'
            $ca3.SessionControls | Should -Contain 'signInFrequency'
            # applicationEnforcedRestrictions isEnabled=false must be excluded; persistentBrowser null excluded
            $ca3.SessionControls | Should -Not -Contain 'applicationEnforcedRestrictions'
            $ca3.SessionControls | Should -Not -Contain 'persistentBrowser'
        }

        It 'filters by state' {
            $r = Get-GkCaPolicyReport -State ReportOnly
            $r.Count | Should -Be 1
            $r[0].Id | Should -Be 'ca3'
        }

        It '-AsReport flattens array columns and adds a timestamp' {
            $ca1 = Get-GkCaPolicyReport -AsReport | Where-Object Id -eq 'ca1'
            $ca1.BuiltInControls   | Should -Be 'mfa'
            $ca1.ClientAppTypes    | Should -Be 'all'
            $ca1.ReportGeneratedUtc | Should -BeOfType ([datetime])
        }
    }
}
