Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkLapsPassword' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('DeviceLocalCredential.Read.All') } }
            Mock Invoke-GkGraphRequest {
                # Discriminate on $select, not on 'credentials': the list URI ends in
                # /deviceLocalCredentials, so a '*credentials*' match would catch both.
                if ($Uri -like '*$select=*') {
                    return @{
                        id = 'dev-1'; deviceName = 'LAPTOP-01'
                        lastBackupDateTime = '2026-08-01T09:00:00Z'; refreshDateTime = '2026-09-01T09:00:00Z'
                        credentials = @(
                            @{ accountName = 'admin'; accountSid = 'S-1-5-21-1'; backupDateTime = '2026-08-01T09:00:00Z'
                               passwordBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('Current-Secret-1')) }
                            @{ accountName = 'admin'; accountSid = 'S-1-5-21-1'; backupDateTime = '2026-07-01T09:00:00Z'
                               passwordBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('Older-Secret-0')) }
                        )
                    }
                }
                return @(
                    @{ id = 'dev-1'; deviceName = 'LAPTOP-01'; lastBackupDateTime = '2026-08-01T09:00:00Z'; refreshDateTime = '2026-09-01T09:00:00Z' }
                    @{ id = 'dev-2'; deviceName = 'LAPTOP-02'; lastBackupDateTime = '2026-08-02T09:00:00Z'; refreshDateTime = '2026-09-02T09:00:00Z' }
                )
            }
        }

        It 'validates only the basic scope when listing' {
            Get-GkLapsPassword | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter {
                $FunctionName -eq 'Get-GkLapsPassword' -and -not $Variant
            }
        }

        It 'validates the password scope when retrieving one' {
            Get-GkLapsPassword -DeviceId 'dev-1' | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $Variant -eq 'Password' }
        }

        It 'returns no password in list mode' {
            $r = @(Get-GkLapsPassword)
            $r.Count | Should -Be 2
            # Property access across a collection yields one entry per row, so filter rather than
            # asserting the projection itself is empty.
            @($r.Password | Where-Object { $_ }) | Should -BeNullOrEmpty
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -notlike '*$select=*' }
        }

        It 'selects the credentials property when retrieving' {
            Get-GkLapsPassword -DeviceId 'dev-1' | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*$select=*credentials*' }
        }

        It 'decodes the base64 password' {
            (Get-GkLapsPassword -DeviceId 'dev-1').Password | Should -Be 'Current-Secret-1'
        }

        It 'returns only the current credential by default' {
            $r = @(Get-GkLapsPassword -DeviceId 'dev-1')
            $r.Count | Should -Be 1
            $r[0].IsCurrent | Should -BeTrue
        }

        It 'includes older credentials with -IncludePrevious' {
            $r = @(Get-GkLapsPassword -DeviceId 'dev-1' -IncludePrevious)
            $r.Count | Should -Be 2
            $r[1].IsCurrent | Should -BeFalse
            $r[1].Password | Should -Be 'Older-Secret-0'
        }

        It 'reports the account the password belongs to' {
            (Get-GkLapsPassword -DeviceId 'dev-1').AccountName | Should -Be 'admin'
        }

        It 'accepts device ids from the pipeline' {
            @([pscustomobject]@{ DeviceId = 'dev-1' }, [pscustomobject]@{ DeviceId = 'dev-2' } | Get-GkLapsPassword).Count | Should -Be 2
        }

        It 'warns and continues when a device has no LAPS credential' {
            Mock Invoke-GkGraphRequest { throw 'not found' }
            $warnings = @()
            $r = Get-GkLapsPassword -DeviceId 'dev-9' -WarningVariable warnings -WarningAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            ($warnings -join ' ') | Should -Match 'dev-9'
        }

        It 'passes through an undecodable password rather than losing it' {
            Mock Invoke-GkGraphRequest {
                @{ id = 'dev-1'; deviceName = 'LAPTOP-01'
                   credentials = @(@{ accountName = 'admin'; passwordBase64 = 'not-valid-base64!!' }) }
            }
            (Get-GkLapsPassword -DeviceId 'dev-1').Password | Should -Be 'not-valid-base64!!'
        }
    }
}
