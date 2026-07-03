Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkDirectoryAudit' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('AuditLog.Read.All') } }
            Mock Invoke-GkGraphRequest {
                @(
                    @{ id = 'a1'; activityDateTime = '2026-07-01T10:00:00Z'; activityDisplayName = 'Add member to role'; category = 'RoleManagement'; result = 'success'
                       initiatedBy = @{ user = @{ userPrincipalName = 'ada@contoso.com' } }; targetResources = @(@{ displayName = 'Bob' }) }
                    @{ id = 'a2'; activityDateTime = '2026-07-01T11:00:00Z'; activityDisplayName = 'Update application'; category = 'ApplicationManagement'; result = 'success'
                       initiatedBy = @{ app = @{ displayName = 'Provisioning Service' } }; targetResources = @(@{ displayName = 'MyApp' }) }
                )
            }
        }

        It 'resolves the initiator (user or app) and targets' {
            $r = Get-GkDirectoryAudit
            $r.Count | Should -Be 2
            ($r | Where-Object Id -eq 'a1').InitiatedBy | Should -Be 'ada@contoso.com'
            ($r | Where-Object Id -eq 'a2').InitiatedBy | Should -Be 'Provisioning Service'
            ($r | Where-Object Id -eq 'a1').Targets     | Should -Contain 'Bob'
        }

        It 'builds a date filter and a category filter server-side' {
            Get-GkDirectoryAudit -Days 3 -Category RoleManagement | Out-Null
            Should -Invoke Invoke-GkGraphRequest -ParameterFilter {
                $Uri -like '*activityDateTime ge*' -and $Uri -like "*category eq 'RoleManagement'*"
            }
        }

        It '-InitiatedBy filters client-side' {
            $r = Get-GkDirectoryAudit -InitiatedBy 'ada@contoso.com'
            $r.Count | Should -Be 1
            $r[0].Id | Should -Be 'a1'
        }
    }
}
