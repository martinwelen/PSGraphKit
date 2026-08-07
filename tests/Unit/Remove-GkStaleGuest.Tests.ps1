Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Remove-GkStaleGuest' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.ReadWrite.All') } }
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*$select=id,userType*') { return @{ id = 'u'; userType = 'Guest' } }
                return $null
            }
        }

        It 'validates the connection' {
            Remove-GkStaleGuest -UserId 'g@contoso.com' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $FunctionName -eq 'Remove-GkStaleGuest' }
        }

        It 'validates the disable scopes by default (no variant)' {
            Remove-GkStaleGuest -UserId 'g@contoso.com' -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { -not $Variant }
        }

        It 'validates the delete scopes under -Delete' {
            Remove-GkStaleGuest -UserId 'g@contoso.com' -Delete -Confirm:$false | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $Variant -eq 'Delete' }
        }

        It 'validates the delete scopes even when -WhatIf suppresses the call' {
            Remove-GkStaleGuest -UserId 'g@contoso.com' -Delete -WhatIf | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $Variant -eq 'Delete' }
        }

        It 'disables a guest by default (PATCH accountEnabled=false)' {
            $r = Remove-GkStaleGuest -UserId 'g@contoso.com' -Confirm:$false
            $r.Action  | Should -Be 'DisableAccount'
            $r.Outcome | Should -Be 'Disabled'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PATCH' -and $Body.accountEnabled -eq $false
            }
        }

        It 'soft-deletes with -Delete (DELETE /users/{id})' {
            $r = Remove-GkStaleGuest -UserId 'g@contoso.com' -Delete -Confirm:$false
            $r.Action  | Should -Be 'SoftDelete'
            $r.Outcome | Should -Be 'Deleted'
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Method -eq 'DELETE' }
        }

        It 'skips a member (userType != Guest) with a warning and Skipped result' {
            Mock Invoke-GkGraphRequest {
                if ($Uri -like '*$select=id,userType*') { return @{ id = 'u'; userType = 'Member' } }
                return $null
            }
            $warnings = @()
            $r = Remove-GkStaleGuest -UserId 'member@contoso.com' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Outcome | Should -Be 'Skipped'
            ($warnings -join ' ') | Should -Match 'not a guest'
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Method -in 'PATCH', 'DELETE' }
        }

        It 'skips the per-user userType re-read when UserType comes from the pipeline' {
            [pscustomobject]@{ UserId = 'g@contoso.com'; UserType = 'Guest' } | Remove-GkStaleGuest -Confirm:$false | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*$select=id,userType*' }
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Method -eq 'PATCH' }
        }

        It '-Force bypasses the guest-type check' {
            Mock Invoke-GkGraphRequest { $null }   # no safety GET expected
            Remove-GkStaleGuest -UserId 'member@contoso.com' -Force -Confirm:$false | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*$select=id,userType*' }
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $Method -eq 'PATCH' }
        }

        It 'makes no write under -WhatIf' {
            Remove-GkStaleGuest -UserId 'g@contoso.com' -WhatIf | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 0 -Exactly -ParameterFilter { $Method -in 'PATCH', 'DELETE' }
        }
    }
}
