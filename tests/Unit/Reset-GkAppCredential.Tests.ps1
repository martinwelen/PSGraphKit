Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Reset-GkAppCredential' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Application.ReadWrite.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*addPassword*') { return @{ keyId = 'new-key'; secretText = 'S3CR3T'; endDateTime = '2027-01-01T00:00:00Z' } }
                return $null
            }
        }

        It 'validates the connection' {
            Reset-GkAppCredential -ApplicationId 'app1' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Reset-GkAppCredential' }
        }

        It 'adds a secret and surfaces the returned secretText' {
            $r = Reset-GkAppCredential -ApplicationId 'app1' -DisplayName 'rot' -Confirm:$false
            $r.Action     | Should -Be 'AddSecret'
            $r.Outcome    | Should -Be 'SecretAdded'
            $r.KeyId      | Should -Be 'new-key'
            $r.SecretText | Should -Be 'S3CR3T'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*/addPassword' -and $Body.passwordCredential.displayName -eq 'rot'
            }
        }

        It 'removes a secret by keyId' {
            $r = Reset-GkAppCredential -ApplicationId 'app1' -RemoveKeyId 'old-key' -Confirm:$false
            $r.Action  | Should -Be 'RemoveSecret'
            $r.Outcome | Should -Be 'SecretRemoved'
            $r.KeyId   | Should -Be 'old-key'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*/removePassword' -and $Body.keyId -eq 'old-key'
            }
        }

        It 'makes no call under -WhatIf' {
            Reset-GkAppCredential -ApplicationId 'app1' -WhatIf | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly
        }

        It 'warns and returns Failed on error' {
            Mock Invoke-GkGraphRequest { throw 'denied' }
            $warnings = @()
            $r = Reset-GkAppCredential -ApplicationId 'app1' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Failed'
            ($warnings -join ' ') | Should -Match 'app1'
        }
    }
}
