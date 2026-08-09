Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'New-GkTemporaryAccessPass' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('UserAuthMethod-TAP.ReadWrite.All') } }
            Mock Invoke-GkGraphRequest {
                @{ id = 'tap-1'; temporaryAccessPass = 'A1b2C3d4'; startDateTime = '2026-08-09T10:00:00Z'
                   lifetimeInMinutes = 60; isUsableOnce = $true }
            }
        }

        It 'validates the connection' {
            New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'New-GkTemporaryAccessPass' }
        }

        It 'POSTs to the temporaryAccessPassMethods collection' {
            New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -Confirm:$false | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*/authentication/temporaryAccessPassMethods'
            }
        }

        It 'returns the passcode' {
            (New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -Confirm:$false).TemporaryAccessPass | Should -Be 'A1b2C3d4'
        }

        It 'defaults to a single-use, one-hour pass' {
            $r = New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -Confirm:$false
            $r.IsUsableOnce | Should -BeTrue
            $r.LifetimeInMinutes | Should -Be 60
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Body.isUsableOnce -eq $true -and $Body.lifetimeInMinutes -eq 60
            }
        }

        It 'inverts -Reusable into isUsableOnce' {
            $r = New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -Reusable -Confirm:$false
            $r.IsUsableOnce | Should -BeFalse
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Body.isUsableOnce -eq $false }
        }

        It 'computes the expiry from the start plus the lifetime' {
            $r = New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -LifetimeInMinutes 120 -Confirm:$false
            ($r.ExpiresDateTime - $r.StartDateTime).TotalMinutes | Should -Be 120
        }

        It 'sends startDateTime only when asked' {
            New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -Confirm:$false | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { -not $Body.ContainsKey('startDateTime') }
        }

        It 'rejects a lifetime outside the API range' {
            { New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -LifetimeInMinutes 5 -Confirm:$false } | Should -Throw
            { New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -LifetimeInMinutes 50000 -Confirm:$false } | Should -Throw
        }

        It 'makes no call under -WhatIf' {
            New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -WhatIf | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'warns and reports Failed when the user already holds a pass' {
            Mock Invoke-GkGraphRequest { throw 'A Temporary Access Pass already exists' }
            $warnings = @()
            $r = New-GkTemporaryAccessPass -UserId 'ada@contoso.com' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            $r.TemporaryAccessPass | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'ada@contoso.com'
        }
    }
}
