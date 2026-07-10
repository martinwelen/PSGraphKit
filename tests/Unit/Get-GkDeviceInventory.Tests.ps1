Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkDeviceInventory' {

        BeforeAll {
            $path = Join-Path $PSScriptRoot '..' 'fixtures' 'devices.json'
            $script:DeviceValue = (Get-Content $path -Raw | ConvertFrom-Json -AsHashtable)['value']
        }

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Device.Read.All') } }
            Mock Invoke-GkGraphRequest { $script:DeviceValue }
        }

        It 'emits typed rows and maps trustType to join type' {
            $r = Get-GkDeviceInventory
            $r.Count | Should -Be 3
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.Device'
            ($r | Where-Object Id -eq 'dev1').JoinType | Should -Be 'AzureADJoined'
            ($r | Where-Object Id -eq 'dev2').JoinType | Should -Be 'Registered'
            ($r | Where-Object Id -eq 'dev3').JoinType | Should -Be 'HybridJoined'   # ServerAd, not "Hybrid"
        }

        It 'computes inactivity and treats a device with no activity as never active' {
            $r = Get-GkDeviceInventory
            ($r | Where-Object Id -eq 'dev1').InactiveDays | Should -BeGreaterThan 0
            $hyb = $r | Where-Object Id -eq 'dev3'
            $hyb.NeverActive  | Should -BeTrue
            $hyb.InactiveDays | Should -BeNullOrEmpty
            $hyb.IsStale      | Should -BeTrue
        }

        It 'filters by join type' {
            $r = Get-GkDeviceInventory -JoinType Registered
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'iPhone-Bob'
        }

        It 'excludes non-stale devices unless requested (recent activity)' {
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'r1'; displayName = 'Recent'; operatingSystem = 'Windows'; trustType = 'AzureAd'
                       approximateLastSignInDateTime = ([datetime]::UtcNow.AddDays(-5).ToString('o')) }
                    @{ id = 's1'; displayName = 'StaleOne'; operatingSystem = 'Windows'; trustType = 'AzureAd'
                       approximateLastSignInDateTime = ([datetime]::UtcNow.AddDays(-300).ToString('o')) }
                )
            }
            $stale = Get-GkDeviceInventory -StaleOnly -StaleDays 90
            $stale.Count | Should -Be 1
            $stale[0].DisplayName | Should -Be 'StaleOne'
        }

        It 'does not flag a freshly-registered device with no sign-in as stale' {
            Mock Invoke-GkGraphRequest {
                @(@{ id = 'new1'; displayName = 'BrandNew'; operatingSystem = 'Windows'; trustType = 'AzureAd'
                     registrationDateTime = ([datetime]::UtcNow.AddDays(-3).ToString('o')) })   # registered, no sign-in yet
            }
            $d = Get-GkDeviceInventory -StaleDays 90
            $d.NeverActive | Should -BeTrue
            $d.IsStale     | Should -BeFalse
        }

        It 'preserves unknown compliance as $null rather than $false' {
            Mock Invoke-GkGraphRequest {
                @(@{ id = 'unk1'; displayName = 'Unknown'; operatingSystem = 'Windows'; trustType = 'AzureAd'
                     approximateLastSignInDateTime = ([datetime]::UtcNow.AddDays(-1).ToString('o')) })   # no isCompliant key
            }
            (Get-GkDeviceInventory)[0].IsCompliant | Should -BeNullOrEmpty
        }

        It 'carries compliance/management/ownership flags' {
            $bob = Get-GkDeviceInventory | Where-Object Id -eq 'dev2'
            $bob.IsCompliant | Should -BeFalse
            $bob.Ownership   | Should -Be 'Personal'
        }

        It 'adds a timestamp with -AsReport' {
            (Get-GkDeviceInventory -AsReport)[0].ReportGeneratedUtc | Should -BeOfType ([datetime])
        }
    }
}
