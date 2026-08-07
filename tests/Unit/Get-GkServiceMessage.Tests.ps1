Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkServiceMessage' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('ServiceMessage.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'MC111'; title = 'Retirement of legacy auth'; services = 'Exchange Online'; category = 'planForChange'
                       severity = 'high'; isMajorChange = $true; actionRequiredByDateTime = ([datetime]::UtcNow.AddDays(10).AddHours(1)).ToString('o')
                       lastModifiedDateTime = '2026-08-01T00:00:00Z'; body = @{ content = '<p>Long HTML</p>'; contentType = 'html' } }
                    @{ id = 'MC222'; title = 'New Teams feature'; services = 'Microsoft Teams'; category = 'stayInformed'
                       severity = 'normal'; isMajorChange = $false
                       lastModifiedDateTime = '2026-08-02T00:00:00Z'; body = @{ content = '<p>FYI</p>'; contentType = 'html' } }
                    @{ id = 'MC333'; title = 'Distant deadline'; services = 'SharePoint'; category = 'planForChange'
                       severity = 'normal'; isMajorChange = $false; actionRequiredByDateTime = ([datetime]::UtcNow.AddDays(200)).ToString('o')
                       lastModifiedDateTime = '2026-08-03T00:00:00Z'; body = @{ content = '<p>Later</p>'; contentType = 'html' } }
                )
            }
        }

        It 'validates the connection' {
            Get-GkServiceMessage | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Get-GkServiceMessage' }
        }

        It 'returns only messages with a deadline under -ActionRequiredOnly' {
            $r = @(Get-GkServiceMessage -ActionRequiredOnly)
            $r.Count | Should -Be 2
            $r.Id | Should -Not -Contain 'MC222'
        }

        It 'combines -ActionRequiredOnly with -ByDays' {
            $r = @(Get-GkServiceMessage -ActionRequiredOnly -ByDays 30)
            $r.Count | Should -Be 1
            $r[0].Id | Should -Be 'MC111'
        }

        It 'computes the days remaining until the deadline' {
            (Get-GkServiceMessage -ActionRequiredOnly)[0].DaysUntilAction | Should -Be 10
        }

        It 'filters category server-side' {
            Get-GkServiceMessage -Category planForChange | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -like "*category eq 'planForChange'*" }
        }

        It 'omits the HTML body by default' {
            (Get-GkServiceMessage)[0].PSObject.Properties.Name | Should -Not -Contain 'Body'
        }

        It 'includes the body content with -IncludeBody' {
            (Get-GkServiceMessage -IncludeBody)[0].Body | Should -Be '<p>Long HTML</p>'
        }

        It 'matches -Service as a substring' {
            $r = @(Get-GkServiceMessage -Service 'Teams')
            $r.Count | Should -Be 1
            $r[0].Id | Should -Be 'MC222'
        }

        It 'passes -First through as MaxResult' {
            Get-GkServiceMessage -First 3 | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $MaxResult -eq 3 }
        }

        It 'leaves DaysUntilAction null when there is no deadline' {
            $r = @(Get-GkServiceMessage | Where-Object Id -eq 'MC222')
            $r[0].DaysUntilAction | Should -BeNullOrEmpty
        }
    }
}
