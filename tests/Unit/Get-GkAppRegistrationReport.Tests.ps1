Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkAppRegistrationReport' {

        BeforeAll {
            $fx = Join-Path $PSScriptRoot '..' 'fixtures'
            $script:AppValue = (Get-Content (Join-Path $fx 'applications.json')          -Raw | ConvertFrom-Json -AsHashtable)['value']
            $script:GraphSp  = (Get-Content (Join-Path $fx 'servicePrincipal-graph.json') -Raw | ConvertFrom-Json -AsHashtable)
        }

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Application.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*servicePrincipals*') { return $script:GraphSp }
                if ($Uri -like '*/applications*')     { return $script:AppValue }
                @()
            }
        }

        It 'emits one typed row per app' {
            $r = Get-GkAppRegistrationReport
            $r.Count | Should -Be 2
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.AppRegistration'
        }

        It 'counts credentials and flags an expired secret' {
            $legacy = Get-GkAppRegistrationReport | Where-Object DisplayName -eq 'Legacy Sync App'
            $legacy.SecretCount            | Should -Be 1
            $legacy.CertificateCount       | Should -Be 0
            $legacy.ExpiredCredentialCount | Should -Be 1
            $legacy.DaysUntilExpiry        | Should -BeLessThan 0
        }

        It 'resolves permission GUIDs and flags high privilege' {
            $legacy = Get-GkAppRegistrationReport | Where-Object DisplayName -eq 'Legacy Sync App'
            $legacy.HasHighPrivilege         | Should -BeTrue
            $legacy.HighPrivilegePermissions | Should -Contain 'Directory.ReadWrite.All'
            $legacy.AppPermissionCount       | Should -Be 1
            $legacy.DelegatedPermissionCount | Should -Be 1

            $reader = Get-GkAppRegistrationReport | Where-Object DisplayName -eq 'Report Reader'
            $reader.HasHighPrivilege | Should -BeFalse
        }

        It 'caches the resource service principal across apps (one lookup)' {
            Get-GkAppRegistrationReport | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*servicePrincipals*' }
        }

        It '-SkipPermissionResolution makes no servicePrincipal calls and leaves high-priv empty' {
            $r = Get-GkAppRegistrationReport -SkipPermissionResolution
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*servicePrincipals*' }
            ($r | Where-Object DisplayName -eq 'Legacy Sync App').HasHighPrivilege | Should -BeFalse
        }

        It '-HighPrivilegeOnly returns only flagged apps' {
            $r = Get-GkAppRegistrationReport -HighPrivilegeOnly
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Legacy Sync App'
        }

        It '-ExpiringOnly selects apps with credentials expiring within the window' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*servicePrincipals*') { return $script:GraphSp }
                @(
                    @{ id = 'x1'; appId = 'x1'; displayName = 'Expiring Soon'; signInAudience = 'AzureADMyOrg'
                       passwordCredentials = @(@{ keyId = 'k'; endDateTime = ([datetime]::UtcNow.AddDays(10).ToString('o')) })
                       keyCredentials = @(); requiredResourceAccess = @() }
                    @{ id = 'x2'; appId = 'x2'; displayName = 'Far Future'; signInAudience = 'AzureADMyOrg'
                       passwordCredentials = @(@{ keyId = 'k'; endDateTime = ([datetime]::UtcNow.AddDays(500).ToString('o')) })
                       keyCredentials = @(); requiredResourceAccess = @() }
                )
            }
            $r = Get-GkAppRegistrationReport -ExpiringInDays 30 -ExpiringOnly
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Expiring Soon'
            $r[0].ExpiringSoonCount | Should -Be 1
        }

        It 'flattens high-priv permissions and adds a timestamp with -AsReport' {
            $legacy = Get-GkAppRegistrationReport -AsReport | Where-Object DisplayName -eq 'Legacy Sync App'
            $legacy.HighPrivilegePermissions | Should -Be 'Directory.ReadWrite.All'
            $legacy.ReportGeneratedUtc        | Should -BeOfType ([datetime])
        }
    }
}
