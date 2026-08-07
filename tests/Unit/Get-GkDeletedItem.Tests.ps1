Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Get-GkDeletedItem' {

        BeforeEach {
            Mock Test-GkConnection { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('User.Read.All') } }
            Mock Invoke-GkGraphRequest {
                # Offset by an extra hour: the cmdlet stamps $now in begin{}, before this mock runs,
                # so a whole-day offset lands just under the boundary and floors down.
                $recent = ([datetime]::UtcNow.AddDays(-2).AddHours(-1)).ToString('o')
                $old = ([datetime]::UtcNow.AddDays(-27).AddHours(-1)).ToString('o')
                @(
                    @{ id = 'd1'; displayName = 'Ada Lovelace'; userPrincipalName = 'ada@contoso.com'; deletedDateTime = $recent }
                    @{ id = 'd2'; displayName = 'Old Account';  userPrincipalName = 'old@contoso.com'; deletedDateTime = $old }
                )
            }
        }

        It 'validates the scopes for the requested type' {
            Get-GkDeletedItem -Type User | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter {
                $FunctionName -eq 'Get-GkDeletedItem' -and $Variant -eq 'User'
            }
        }

        It 'validates a different scope set for a different type' {
            Get-GkDeletedItem -Type Group | Out-Null
            Should -Invoke Test-GkConnection -Times 1 -Exactly -ParameterFilter { $Variant -eq 'Group' }
        }

        It 'builds the type cast segment, not a filter' {
            Get-GkDeletedItem -Type Application | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -eq '/directory/deletedItems/microsoft.graph.application'
            }
        }

        It 'lower-cases only the first letter of a compound type' {
            Get-GkDeletedItem -Type ServicePrincipal | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -eq '/directory/deletedItems/microsoft.graph.servicePrincipal'
            }
        }

        It 'computes the remaining restore window from the 30-day retention' {
            $r = @(Get-GkDeletedItem -Type User)
            $r[0].DaysSinceDeleted | Should -Be 2
            $r[0].DaysUntilPurge   | Should -Be 28
            $r[1].DaysUntilPurge   | Should -Be 3
        }

        It 'filters to objects about to be purged with -ExpiringInDays' {
            $r = @(Get-GkDeletedItem -Type User -ExpiringInDays 5)
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Old Account'
        }

        It 'filters to recent deletions with -DeletedWithinDays' {
            $r = @(Get-GkDeletedItem -Type User -DeletedWithinDays 7)
            $r.Count | Should -Be 1
            $r[0].DisplayName | Should -Be 'Ada Lovelace'
        }

        It 'passes -First through as MaxResult' {
            Get-GkDeletedItem -Type User -First 5 | Out-Null
            Should -Invoke Invoke-GkGraphRequest -Times 1 -Exactly -ParameterFilter { $MaxResult -eq 5 }
        }

        It 'rejects a type Graph has no cast segment for' {
            { Get-GkDeletedItem -Type Device } | Should -Throw
        }

        It 'adds a report stamp with -AsReport' {
            (Get-GkDeletedItem -Type User -AsReport)[0].ReportGeneratedUtc | Should -BeOfType [datetime]
        }
    }
}
