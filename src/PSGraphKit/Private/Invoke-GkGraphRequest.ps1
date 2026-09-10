function Invoke-GkGraphRequest {
    <#
    .SYNOPSIS
        Single internal chokepoint for all Microsoft Graph traffic in PSGraphKit.
    .DESCRIPTION
        Centralizes, on top of the Invoke-GkRawGraphCall seam:
          * Base-URL/version prefixing (relative URIs) and passthrough of absolute nextLinks.
          * Automatic pagination: follows @odata.nextLink to completion, re-injecting custom
            headers (e.g. ConsistencyLevel) on every page since Graph does not carry them over.
          * 429/503 throttling: honors Retry-After, else bounded exponential backoff with jitter.
          * Curated error translation for permission (403), auth (401), and query (400) failures,
            enriched with the caller's active roles, while preserving the raw Graph error/request-id.
          * Optional one-shot beta fallback (opt-in, off by default; unused in Phase 1).

        Not exported. Public functions call this, never Invoke-MgGraphRequest directly.
    .OUTPUTS
        By default, the flattened array of collection items (all pages). With -Raw, the raw
        first-page body (Hashtable, or a scalar for /$count).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Uri,

        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string] $Method = 'GET',

        [hashtable] $Body,

        [hashtable] $Headers,

        [ValidateSet('v1.0', 'beta')]
        [string] $ApiVersion = 'v1.0',

        [switch] $BetaFallback,

        # Return the raw first-page body instead of accumulating/unwrapping 'value'.
        # Used for single-entity reads and /$count endpoints.
        [switch] $Raw,

        [ValidateRange(0, 10)]
        [int] $MaxRetry = 5,

        # Cap the number of collection items returned (0 = unlimited): stop following @odata.nextLink
        # once this many have accumulated, then trim to exactly this count. For "N most-recent" reads
        # over time-ordered logs (Graph returns them newest-first).
        [ValidateRange(0, 500000)]
        [int] $MaxResult = 0,

        # Name of the public function on whose behalf this runs; drives role hints in 403 messages.
        [string] $CallerFunction,

        # Set by Get-GkCurrentUserRole to prevent recursive role enrichment on its own 403.
        [switch] $SuppressRoleEnrichment
    )

    # --- Build the initial URI -------------------------------------------------------------
    if ($Uri -match '^https?://') {
        $current = $Uri
    }
    else {
        $current = '{0}/{1}/{2}' -f $script:GkGraphBaseUri, $ApiVersion, $Uri.TrimStart('/')
    }

    $doPaging  = (-not $Raw) -and ($Method -eq 'GET')   # only GET collections paginate
    $triedBeta = $false
    $items     = [System.Collections.Generic.List[object]]::new()
    $attempt   = 0

    while ($true) {

        $requestParams = @{ Method = $Method; Uri = $current }
        if ($Headers) { $requestParams['Headers'] = $Headers }   # re-passed every page on purpose
        if ($Body)    { $requestParams['Body']    = $Body }

        try {
            $callResult = Invoke-GkRawGraphCall -RequestParams $requestParams
        }
        catch {
            # Transport-level failure (DNS, TLS, no connectivity) — no HTTP status available.
            $ex = [System.Exception]::new(
                "PSGraphKit could not reach Microsoft Graph at '$current': $($_.Exception.Message)", $_.Exception)
            $er = [System.Management.Automation.ErrorRecord]::new(
                $ex, 'GkGraph_TransportFailure', [System.Management.Automation.ErrorCategory]::ConnectionError, $current)
            $PSCmdlet.ThrowTerminatingError($er)
        }

        $sc       = $callResult.StatusCode
        $rh       = $callResult.Headers
        $response = $callResult.Body

        # --- Success ----------------------------------------------------------------------
        if ($sc -ge 200 -and $sc -lt 300) {
            $attempt = 0
            if ($Raw) { return $response }

            if ($response -is [System.Collections.IDictionary] -and $response.Contains('value')) {
                foreach ($v in @($response['value'])) { $items.Add($v) }
                if ($MaxResult -gt 0 -and $items.Count -ge $MaxResult) {
                    return , @($items.ToArray() | Select-Object -First $MaxResult)   # cap reached; stop paging
                }
                $next = if ($response.Contains('@odata.nextLink')) { $response['@odata.nextLink'] } else { $null }
                if ($doPaging -and $next) {
                    $current = [string]$next
                    continue
                }
                return , $items.ToArray()
            }

            # Single entity or scalar response — nothing to page.
            return $response
        }

        # --- Throttling / transient (429, 503) --------------------------------------------
        if ($sc -eq 429 -or $sc -eq 503) {
            $attempt++
            if ($attempt -gt $MaxRetry) {
                $ex = [System.Exception]::new(
                    "Microsoft Graph is throttling PSGraphKit (HTTP $sc) and did not recover after $MaxRetry retries calling '$current'. Try again later or narrow the query.")
                $er = [System.Management.Automation.ErrorRecord]::new(
                    $ex, "GkGraph_Throttled_$sc", [System.Management.Automation.ErrorCategory]::LimitsExceeded, $current)
                $PSCmdlet.ThrowTerminatingError($er)
            }

            $retryAfter = Get-GkResponseHeader $rh 'Retry-After'
            [int] $ra = 0
            if ($retryAfter -and [int]::TryParse($retryAfter, [ref] $ra) -and $ra -gt 0) {
                $delay = [double] $ra
            }
            else {
                $delay = [Math]::Min([Math]::Pow(2, $attempt), 60) + (Get-Random -Minimum 0 -Maximum 1000) / 1000.0
            }
            Write-Verbose ("PSGraphKit: HTTP {0} on attempt {1}/{2}; backing off {3:N1}s." -f $sc, $attempt, $MaxRetry, $delay)
            Start-Sleep -Seconds $delay
            continue
        }

        # --- One-shot beta fallback (opt-in, off by default; unused in Phase 1) -----------
        if ($BetaFallback -and -not $triedBeta -and ($sc -eq 404 -or $sc -eq 400) -and $current -match '/v1\.0/') {
            $triedBeta = $true
            $current = $current -replace '/v1\.0/', '/beta/'
            Write-Verbose "PSGraphKit: v1.0 returned $sc; retrying once against beta ($current)."
            continue
        }

        # --- Curated error translation (401 / 403 / 400 / 404 / other) --------------------
        $code   = $null; $gmsg = $null; $reqId = $null
        if ($response -is [System.Collections.IDictionary] -and $response.Contains('error')) {
            $errObj = $response['error']
            if ($errObj -is [System.Collections.IDictionary]) {
                if ($errObj.Contains('code'))    { $code = [string]$errObj['code'] }
                if ($errObj.Contains('message')) { $gmsg = [string]$errObj['message'] }
                if ($errObj.Contains('innerError') -and $errObj['innerError'] -is [System.Collections.IDictionary]) {
                    $inner = $errObj['innerError']
                    foreach ($k in 'request-id', 'client-request-id') {
                        if ($inner.Contains($k)) { $reqId = [string]$inner[$k]; break }
                    }
                }
            }
        }

        $ctx = Get-MgContext
        switch ($sc) {
            401 {
                $message  = "Microsoft Graph returned 401 Unauthorized calling '$current': your session is expired or invalid. Run Connect-MgGraph again."
                $category = [System.Management.Automation.ErrorCategory]::AuthenticationError
            }
            403 {
                $roleLine = ''
                if (-not $SuppressRoleEnrichment) {
                    if ($ctx -and $ctx.AuthType -eq 'Delegated') {
                        $roles = Get-GkCurrentUserRole
                        if ($roles) {
                            $roleLine = "You currently hold active directory role(s): $($roles -join ', '). "
                        }
                        else {
                            $roleLine = 'Could not read your active roles (a required role may be PIM-eligible but not activated). '
                        }
                    }
                    elseif ($ctx -and $ctx.AuthType -eq 'AppOnly') {
                        $roleLine = 'This is an app-only session; effective access is the set of application permissions granted to the service principal. '
                    }
                    if ($CallerFunction -and $script:GkScopeMap.ContainsKey($CallerFunction)) {
                        $entry = $script:GkScopeMap[$CallerFunction]
                        if ($entry.DelegatedOnly -and $ctx -and $ctx.AuthType -eq 'AppOnly') {
                            $roleLine += "$CallerFunction relies on a delegated-only Graph API; reconnect with an interactive/delegated session. "
                        }
                        if ($entry.RoleHints -and $entry.RoleHints.Count -gt 0) {
                            $roleLine += "This operation typically needs one of these roles: $($entry.RoleHints -join ', ') (or a custom role granting the equivalent action). "
                        }
                    }
                }
                $message  = "Microsoft Graph denied access (403) calling '$current'. Your token has the scope, but access was refused. ${roleLine}Underlying Graph error: $code - $gmsg."
                $category = [System.Management.Automation.ErrorCategory]::PermissionDenied
            }
            404 {
                $message  = "Microsoft Graph returned 404 Not Found calling '$current': $code - $gmsg."
                $category = [System.Management.Automation.ErrorCategory]::ObjectNotFound
            }
            400 {
                $message  = "Microsoft Graph rejected the request (400) calling '$current': $code - $gmsg. If this is an advanced query, it should include ConsistencyLevel:eventual and `$count=true."
                $category = [System.Management.Automation.ErrorCategory]::InvalidArgument
            }
            default {
                $message  = "Microsoft Graph request failed (HTTP $sc) calling '$current': $code - $gmsg."
                $category = [System.Management.Automation.ErrorCategory]::InvalidOperation
            }
        }
        if ($reqId) { $message += " (request-id: $reqId)" }

        $ex = [System.Exception]::new($message)
        $er = [System.Management.Automation.ErrorRecord]::new(
            $ex, "GkGraph_$($sc)_$($code)", $category, $current)
        $er.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($message)
        $PSCmdlet.ThrowTerminatingError($er)
    }
}
