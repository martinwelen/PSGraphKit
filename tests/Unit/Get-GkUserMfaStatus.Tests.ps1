Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkUserMfaStatus' {

        BeforeAll {
            $path = Join-Path $PSScriptRoot '..' 'fixtures' 'userRegistrationDetails.json'
            $script:RegValue = (Get-Content $path -Raw | ConvertFrom-Json -AsHashtable)['value']
        }

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('AuditLog.Read.All') } }
            Mock Invoke-GkGraphRequest { $script:RegValue }
        }

        It 'emits typed rows with capability flags' {
            $r = Get-GkUserMfaStatus
            $r.Count | Should -Be 3
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.UserMfaStatus'
            ($r | Where-Object UserPrincipalName -eq 'ada@contoso.com').IsMfaCapable | Should -BeTrue
            ($r | Where-Object UserPrincipalName -eq 'noel@contoso.com').IsMfaCapable | Should -BeFalse
        }

        It 'exposes registered methods as an array with a count' {
            $ada = Get-GkUserMfaStatus | Where-Object UserPrincipalName -eq 'ada@contoso.com'
            $ada.MethodsRegistered | Should -Contain 'fido2SecurityKey'
            $ada.MethodCount       | Should -Be 3
            $ada.MethodsRegistered | Should -BeOfType ([string])  # each element is a string
        }

        It 'pushes a server-side filter for -NotMfaCapableOnly' {
            Get-GkUserMfaStatus -NotMfaCapableOnly | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly `
                -ParameterFilter { $Uri -like '*isMfaCapable eq false*' }
        }

        It 'combines admin and capability filters' {
            Get-GkUserMfaStatus -NotMfaCapableOnly -AdminsOnly | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly `
                -ParameterFilter { $Uri -like '*isMfaCapable eq false and isAdmin eq true*' }
        }

        It 'flattens methods and adds a timestamp with -AsReport' {
            $ada = Get-GkUserMfaStatus -AsReport | Where-Object UserPrincipalName -eq 'ada@contoso.com'
            $ada.MethodsRegistered   | Should -Be 'microsoftAuthenticatorPush; fido2SecurityKey; mobilePhone'
            $ada.ReportGeneratedUtc  | Should -BeOfType ([datetime])
        }
    }
}
