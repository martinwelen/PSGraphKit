Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'Invoke-GkGraphRequest' {

        Context 'Pagination' {
            It 'follows @odata.nextLink and flattens value across pages' {
                $script:call = 0
                Mock Invoke-GkRawGraphCall {
                    $script:call++
                    if ($script:call -eq 1) {
                        [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{
                            value             = @(@{ id = 1 }, @{ id = 2 })
                            '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?$skiptoken=x'
                        } }
                    }
                    else {
                        [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{ value = @(@{ id = 3 }) } }
                    }
                }

                $result = Invoke-GkGraphRequest -Uri '/users'

                $result.Count | Should -Be 3
                Should -Invoke Invoke-GkRawGraphCall -Times 2 -Exactly
            }

            It 'caps at -MaxResult and stops paging once reached' {
                $script:call = 0
                Mock Invoke-GkRawGraphCall {
                    $script:call++
                    [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{
                        value             = @(@{ id = "p$script:call-a" }, @{ id = "p$script:call-b" })
                        '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?$skiptoken=x'
                    } }
                }

                $result = Invoke-GkGraphRequest -Uri '/users' -MaxResult 3

                # page 1 -> 2 items (< 3, keep paging); page 2 -> 4 items (>= 3, stop) -> trimmed to 3.
                @($result).Count | Should -Be 3
                Should -Invoke Invoke-GkRawGraphCall -Times 2 -Exactly
            }

            It 're-injects custom headers (ConsistencyLevel) on every page request' {
                $script:call = 0
                Mock Invoke-GkRawGraphCall {
                    $script:call++
                    if ($script:call -eq 1) {
                        [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{
                            value             = @(@{ id = 1 })
                            '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?$skiptoken=y'
                        } }
                    }
                    else {
                        [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{ value = @(@{ id = 2 }) } }
                    }
                }

                Invoke-GkGraphRequest -Uri '/users' -Headers @{ ConsistencyLevel = 'eventual' } | Out-Null

                Should -Invoke Invoke-GkRawGraphCall -Times 2 -Exactly `
                    -ParameterFilter { $RequestParams.Headers.ConsistencyLevel -eq 'eventual' }
            }
        }

        Context 'Raw' {
            It '-Raw returns the untouched first-page body' {
                Mock Invoke-GkRawGraphCall {
                    [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{ '@odata.count' = 42; value = @(1, 2) } }
                }
                $r = Invoke-GkGraphRequest -Uri '/groups/abc/members/$count' -Raw
                $r['@odata.count'] | Should -Be 42
            }
        }

        Context 'Write methods (PATCH/DELETE/POST)' {
            It 'sends PATCH with a JSON body and returns the entity' {
                Mock Invoke-GkRawGraphCall {
                    [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{ id = 'u1'; accountEnabled = $false } }
                }
                $r = Invoke-GkGraphRequest -Method PATCH -Uri '/users/u1' -Body @{ accountEnabled = $false } -Raw
                $r['accountEnabled'] | Should -BeFalse
                Should -Invoke Invoke-GkRawGraphCall -Times 1 -Exactly -ParameterFilter {
                    $RequestParams.Method -eq 'PATCH' -and $RequestParams.Body.accountEnabled -eq $false
                }
            }

            It 'handles a 204 No Content (DELETE) without error' {
                Mock Invoke-GkRawGraphCall {
                    [pscustomobject]@{ StatusCode = 204; Headers = @{}; Body = $null }
                }
                { Invoke-GkGraphRequest -Method DELETE -Uri '/users/u1' } | Should -Not -Throw
                (Invoke-GkGraphRequest -Method DELETE -Uri '/users/u1') | Should -BeNullOrEmpty
            }

            It 'does not paginate a non-GET response even if it carries a nextLink' {
                Mock Invoke-GkRawGraphCall {
                    [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{
                        value             = @(@{ id = 1 })
                        '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/x?$skiptoken=z'
                    } }
                }
                Invoke-GkGraphRequest -Method POST -Uri '/x' -Body @{ a = 1 } | Out-Null
                Should -Invoke Invoke-GkRawGraphCall -Times 1 -Exactly
            }
        }

        Context 'Throttling' {
            It 'retries on 429 honoring Retry-After, then succeeds' {
                Mock Start-Sleep {}
                $script:call = 0
                Mock Invoke-GkRawGraphCall {
                    $script:call++
                    if ($script:call -eq 1) {
                        [pscustomobject]@{ StatusCode = 429; Headers = @{ 'Retry-After' = '1' }; Body = @{} }
                    }
                    else {
                        [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{ value = @(@{ id = 'ok' }) } }
                    }
                }

                $r = Invoke-GkGraphRequest -Uri '/users'

                @($r)[0].id | Should -Be 'ok'
                Should -Invoke Start-Sleep -Times 1 -Exactly
                Should -Invoke Invoke-GkRawGraphCall -Times 2 -Exactly
            }

            It 'gives up after MaxRetry throttles and throws LimitsExceeded' {
                Mock Start-Sleep {}
                Mock Invoke-GkRawGraphCall {
                    [pscustomobject]@{ StatusCode = 429; Headers = @{}; Body = @{} }
                }

                { Invoke-GkGraphRequest -Uri '/users' -MaxRetry 2 } |
                    Should -Throw -ExpectedMessage '*throttling*'
                Should -Invoke Start-Sleep -Times 2 -Exactly
            }
        }

        Context 'Error translation' {
            It '401 tells the caller to reconnect' {
                Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @() } }
                Mock Invoke-GkRawGraphCall {
                    [pscustomobject]@{ StatusCode = 401; Headers = @{}; Body = @{ error = @{ code = 'InvalidAuthenticationToken'; message = 'expired' } } }
                }
                { Invoke-GkGraphRequest -Uri '/users' } | Should -Throw -ExpectedMessage '*Connect-MgGraph again*'
            }

            It '403 names active roles, required roles, and preserves request-id' {
                Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated'; Scopes = @('Policy.Read.All') } }
                Mock Get-GkCurrentUserRole { @('Global Reader') }
                Mock Invoke-GkRawGraphCall {
                    [pscustomobject]@{ StatusCode = 403; Headers = @{}; Body = @{ error = @{
                        code       = 'Authorization_RequestDenied'
                        message    = 'Insufficient privileges to complete the operation.'
                        innerError = @{ 'request-id' = 'abc-123' }
                    } } }
                }

                $err = $null
                try {
                    Invoke-GkGraphRequest -Uri '/identity/conditionalAccess/policies' -CallerFunction 'Get-GkCaPolicyReport'
                }
                catch { $err = $_ }

                $err | Should -Not -BeNullOrEmpty
                $err.Exception.Message | Should -Match 'denied access \(403\)'
                $err.Exception.Message | Should -Match 'Global Reader'
                $err.Exception.Message | Should -Match 'Conditional Access Administrator'
                $err.Exception.Message | Should -Match 'request-id: abc-123'
            }

            It '403 under app-only mentions delegated for a delegated-only function' {
                Mock Get-MgContext { [pscustomobject]@{ AuthType = 'AppOnly'; Scopes = @('Directory.Read.All') } }
                Mock Invoke-GkRawGraphCall {
                    [pscustomobject]@{ StatusCode = 403; Headers = @{}; Body = @{ error = @{ code = 'Authorization_RequestDenied'; message = 'denied' } } }
                }
                { Invoke-GkGraphRequest -Uri '/users/x/licenseDetails' -CallerFunction 'Get-GkUserAccessReport' } |
                    Should -Throw -ExpectedMessage '*delegated-only*'
            }
        }
    }
}
