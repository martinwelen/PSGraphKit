Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkServicePrincipalReport' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Application.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*oauth2PermissionGrants*') {
                    return @(
                        @{ clientId = 'sp1'; consentType = 'AllPrincipals'; scope = 'User.Read' }
                        @{ clientId = 'sp1'; consentType = 'Principal'; scope = 'Mail.Read' }
                    )
                }
                return @(
                    @{ id = 'sp1'; appId = 'a1'; displayName = 'Risky App'; accountEnabled = $true; servicePrincipalType = 'Application'; appRoleAssignmentRequired = $false; tags = @('WindowsAzureActiveDirectoryIntegratedApp') }
                    @{ id = 'sp2'; appId = 'a2'; displayName = 'MI'; accountEnabled = $true; servicePrincipalType = 'ManagedIdentity'; appRoleAssignmentRequired = $true; tags = @() }
                )
            }
        }

        It 'emits typed rows' {
            $r = Get-GkServicePrincipalReport
            $r.Count | Should -Be 2
            $r[0].PSTypeNames[0] | Should -Be 'PSGraphKit.ServicePrincipal'
        }

        It 'filters by type' {
            (Get-GkServicePrincipalReport -Type ManagedIdentity).Count | Should -Be 1
        }

        It 'applies -Type server-side (servicePrincipalType filter in the query)' {
            Get-GkServicePrincipalReport -Type ManagedIdentity | Out-Null
            Should -Invoke Invoke-GkGraphRequest -ParameterFilter { $Uri -like "*servicePrincipalType eq 'ManagedIdentity'*" }
        }

        It 'keeps a single-element array field as an array (not unrolled to a scalar)' {
            $sp1 = Get-GkServicePrincipalReport | Where-Object Id -eq 'sp1'
            ($sp1.Tags -is [array]) | Should -BeTrue   # one tag -> still an array
            $sp1.Tags.Count | Should -Be 1
        }

        It 'does not query consent grants unless -IncludeConsentGrants' {
            Get-GkServicePrincipalReport | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*oauth2PermissionGrants*' }
        }

        It 'annotates tenant-wide consent with -IncludeConsentGrants' {
            $sp1 = Get-GkServicePrincipalReport -IncludeConsentGrants | Where-Object Id -eq 'sp1'
            $sp1.DelegatedGrantCount  | Should -Be 2
            $sp1.HasTenantWideConsent | Should -BeTrue
        }
    }
}
