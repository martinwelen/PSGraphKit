Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkCrossTenantAccess' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Policy.Read.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*crossTenantAccessPolicy/default*') {
                    return @{ isServiceDefault = $true; inboundTrust = @{ isMfaAccepted = $false; isCompliantDeviceAccepted = $false; isHybridAzureADJoinedDeviceAccepted = $false } }
                }
                if ($Uri -like '*partners*') {
                    return @(@{ tenantId = 'partner-tenant-1'; inboundTrust = @{ isMfaAccepted = $true; isCompliantDeviceAccepted = $true; isHybridAzureADJoinedDeviceAccepted = $false } })
                }
                @()
            }
        }

        It 'emits a Default row plus one per partner' {
            $r = Get-GkCrossTenantAccess
            $r.Count | Should -Be 2
            ($r | Where-Object Scope -eq 'Default').IsServiceDefault | Should -BeTrue
        }

        It 'surfaces inbound trust flags for a partner' {
            $p = Get-GkCrossTenantAccess | Where-Object Scope -eq 'partner-tenant-1'
            $p.TrustMfa                 | Should -BeTrue
            $p.TrustCompliantDevice     | Should -BeTrue
            $p.TrustHybridJoinedDevice  | Should -BeFalse
        }
    }
}
