function Test-GkConnection {
    <#
    .SYNOPSIS
        Pre-flight validation before a public function makes Graph calls: confirms an active
        session, the required scopes (by capability group), and delegated-only constraints.
    .DESCRIPTION
        Throws an actionable, terminating error when the caller is not connected, is missing a
        required scope, or is app-only against a delegated-only function. On success, returns
        the IAuthContext. Called at the top of every public function.

        Scope checking uses capability groups from $script:GkScopeMap: the caller must hold at
        least one scope from each group, so a broad scope (Directory.Read.All) satisfies narrower
        needs without a false failure.
    .OUTPUTS
        Microsoft.Graph.PowerShell.Authentication.IAuthContext
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FunctionName
    )

    $ctx = Get-MgContext
    if (-not $ctx) {
        $connectHint = Get-GkConnectScopeHint -FunctionName $FunctionName
        $ex = [System.Exception]::new(
            "Not connected to Microsoft Graph. Run: Connect-MgGraph -Scopes $connectHint")
        $er = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'GkNotConnected', [System.Management.Automation.ErrorCategory]::AuthenticationError, $FunctionName)
        $PSCmdlet.ThrowTerminatingError($er)
    }

    if (-not $script:GkScopeMap.ContainsKey($FunctionName)) {
        # Unknown function name — nothing to validate beyond an active session.
        return $ctx
    }
    $entry = $script:GkScopeMap[$FunctionName]

    # Auth-type constraint: delegated-only APIs cannot be served app-only.
    if ($entry.DelegatedOnly -and $ctx.AuthType -eq 'AppOnly') {
        $ex = [System.Exception]::new(
            "$FunctionName requires a delegated (interactive) session — it reads a Graph API with no application permission (e.g. licenseDetails). You are connected app-only. Reconnect with: Connect-MgGraph -Scopes $(Get-GkConnectScopeHint -FunctionName $FunctionName)")
        $er = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'GkDelegatedOnly', [System.Management.Automation.ErrorCategory]::PermissionDenied, $FunctionName)
        $PSCmdlet.ThrowTerminatingError($er)
    }

    # Scope capability groups: need at least one scope from each group.
    $granted = @($ctx.Scopes)
    $missingGroups = foreach ($group in $entry.Groups) {
        $has = $false
        foreach ($s in $group.Any) {
            if ($granted -contains $s) { $has = $true; break }
        }
        if (-not $has) { $group }
    }

    if ($missingGroups) {
        $detail = ($missingGroups | ForEach-Object { "to $($_.For): one of [$($_.Any -join ', ')]" }) -join '; '
        $connectHint = Get-GkConnectScopeHint -FunctionName $FunctionName
        $ex = [System.Exception]::new(
            "Missing Graph scope(s) for ${FunctionName}: $detail. Run: Connect-MgGraph -Scopes $connectHint")
        $er = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'GkMissingScope', [System.Management.Automation.ErrorCategory]::PermissionDenied, $FunctionName)
        $PSCmdlet.ThrowTerminatingError($er)
    }

    return $ctx
}

function Get-GkConnectScopeHint {
    <#
    .SYNOPSIS
        Build a comma-joined least-effort scope string for a Connect-MgGraph hint: the first
        (least-privileged, as ordered in the map) scope from each capability group.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $FunctionName
    )
    if (-not $script:GkScopeMap.ContainsKey($FunctionName)) { return 'User.Read.All' }
    $entry = $script:GkScopeMap[$FunctionName]
    $scopes = foreach ($group in $entry.Groups) { @($group.Any)[0] }
    $scopes = @($scopes | Where-Object { $_ } | Select-Object -Unique)
    if (-not $scopes) { return 'User.Read' }
    return ($scopes -join ',')
}
