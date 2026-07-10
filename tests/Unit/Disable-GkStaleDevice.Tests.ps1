Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Disable-GkStaleDevice' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Directory.AccessAsUser.All') } }
            Mock Invoke-GkGraphRequest { $null }
        }

        It 'validates the connection' {
            Disable-GkStaleDevice -DeviceId 'd1' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Disable-GkStaleDevice' }
        }

        It 'disables by default (PATCH /devices/{id} accountEnabled=false)' {
            $r = Disable-GkStaleDevice -DeviceId 'd1' -Confirm:$false
            $r.Action  | Should -Be 'DisableDevice'
            $r.Outcome | Should -Be 'Disabled'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PATCH' -and $Uri -like '*/devices/d1' -and $Body.accountEnabled -eq $false
            }
        }

        It 'soft-deletes with -Delete (DELETE /devices/{id})' {
            $r = Disable-GkStaleDevice -DeviceId 'd1' -Delete -Confirm:$false
            $r.Action  | Should -Be 'DeleteDevice'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Method -eq 'DELETE' -and $Uri -like '*/devices/d1' }
        }

        It 'makes no call under -WhatIf' {
            Disable-GkStaleDevice -DeviceId 'd1' -WhatIf | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'binds the object Id, not the deviceId GUID, from the Get-GkDeviceInventory pipeline shape' {
            # Get-GkDeviceInventory emits BOTH Id (object id) and DeviceId (deviceId GUID). /devices/{id}
            # needs the object id; binding the deviceId GUID would 404. PowerShell binds the formal name
            # (Id) over the alias (DeviceId), so the object id must be the parameter's formal name.
            $devs = @(
                [pscustomobject]@{ Id = 'obj-1'; DeviceId = 'dev-guid-1' }
                [pscustomobject]@{ Id = 'obj-2'; DeviceId = 'dev-guid-2' }
            )
            $r = $devs | Disable-GkStaleDevice -Confirm:$false
            $r.Count | Should -Be 2
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*/devices/obj-1' }
            Should -Not -Invoke Invoke-GkGraphRequest -ParameterFilter { $Uri -like '*dev-guid*' }
        }

        It 'warns and returns Failed on error' {
            Mock Invoke-GkGraphRequest { throw 'denied' }
            $warnings = @()
            $r = Disable-GkStaleDevice -DeviceId 'd1' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            ($warnings -join ' ') | Should -Match 'd1'
        }
    }
}
