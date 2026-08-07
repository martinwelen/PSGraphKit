Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkUserAuthMethod' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('UserAuthenticationMethod.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ '@odata.type' = '#microsoft.graph.passwordAuthenticationMethod'; id = 'p1'; createdDateTime = '2024-01-05T10:00:00Z' }
                    @{ '@odata.type' = '#microsoft.graph.phoneAuthenticationMethod'; id = 'ph1'; phoneNumber = '+46 70 000 00 00' }
                    @{ '@odata.type' = '#microsoft.graph.fido2AuthenticationMethod'; id = 'f1'; displayName = 'YubiKey 5'; model = 'YubiKey 5 NFC' }
                )
            }
        }

        It 'validates the connection' {
            Get-GkUserAuthMethod -UserId 'ada@contoso.com' | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Get-GkUserAuthMethod' }
        }

        It 'maps @odata.type to a readable method name' {
            $r = @(Get-GkUserAuthMethod -UserId 'ada@contoso.com')
            $r.MethodType | Should -Be @('Password', 'Phone', 'Fido2')
        }

        It 'takes the first populated label as Detail' {
            $r = @(Get-GkUserAuthMethod -UserId 'ada@contoso.com')
            $r[1].Detail | Should -Be '+46 70 000 00 00'
            $r[2].Detail | Should -Be 'YubiKey 5'
        }

        It 'parses createdDateTime into a real datetime' {
            (Get-GkUserAuthMethod -UserId 'ada@contoso.com')[0].CreatedDateTime | Should -BeOfType [datetime]
        }

        It 'filters by -MethodType' {
            $r = @(Get-GkUserAuthMethod -UserId 'ada@contoso.com' -MethodType Fido2)
            $r.Count | Should -Be 1
            $r[0].Id | Should -Be 'f1'
        }

        It 'percent-encodes a guest UPN' {
            Get-GkUserAuthMethod -UserId 'bob_x.com#EXT#@contoso.onmicrosoft.com' | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -notlike '*#*' -and $Uri -like '*%23EXT%23*' }
        }

        It 'warns and continues when a user cannot be read' {
            Mock Invoke-GkGraphRequest { throw 'forbidden' }
            $warnings = @()
            $r = Get-GkUserAuthMethod -UserId 'ada@contoso.com' -WarningVariable warnings -WarningAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'ada@contoso.com'
        }

        It 'falls back to the raw type for an unmapped method' {
            Mock Invoke-GkGraphRequest { @(@{ '@odata.type' = '#microsoft.graph.brandNewAuthenticationMethod'; id = 'n1' }) }
            (Get-GkUserAuthMethod -UserId 'ada@contoso.com').MethodType | Should -Be 'brandNewAuthenticationMethod'
        }
    }
}
