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

        A function whose scope requirement depends on what it was asked to do (e.g.
        Remove-GkStaleGuest disabling vs deleting) passes -Variant; the map is then keyed
        '<FunctionName>:<Variant>', falling back to '<FunctionName>' when no such entry exists.

        Public functions pass -Caller $PSCmdlet so the terminating error is raised from the cmdlet
        the user actually typed. Without it the failure is attributed to this private helper, and
        PowerShell's ConciseView renders a code frame pointing into Test-GkConnection.ps1, which
        reads like a leaked stack trace.
    .OUTPUTS
        Microsoft.Graph.PowerShell.Authentication.IAuthContext
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FunctionName,

        # Selects an action-specific scope entry; ignored when the map has no variant key.
        [string] $Variant,

        # The calling public cmdlet's $PSCmdlet, so errors are attributed to it rather than here.
        [System.Management.Automation.PSCmdlet] $Caller
    )

    # Raise from the caller when we were given one, so the error names the user's cmdlet.
    $thrower = $PSCmdlet
    if ($Caller) { $thrower = $Caller }

    $ctx = Get-MgContext
    $mapKey = Resolve-GkScopeMapKey -FunctionName $FunctionName -Variant $Variant
    if (-not $ctx) {
        $ex = [System.Exception]::new(
            "Not connected to Microsoft Graph. Run: $(Get-GkConnectCommandHint -FunctionName $FunctionName -Variant $Variant)")
        $er = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'GkNotConnected', [System.Management.Automation.ErrorCategory]::AuthenticationError, $FunctionName)
        $thrower.ThrowTerminatingError($er)
    }

    if (-not $mapKey) {
        # Unknown function name — nothing to validate beyond an active session.
        return $ctx
    }
    $entry = $script:GkScopeMap[$mapKey]

    # Auth-type constraint: delegated-only APIs cannot be served app-only.
    if ($entry.DelegatedOnly -and $ctx.AuthType -eq 'AppOnly') {
        $ex = [System.Exception]::new(
            "$FunctionName requires a delegated (interactive) session — it reads a Graph API with no application permission (e.g. licenseDetails). You are connected app-only. Reconnect with: $(Get-GkConnectCommandHint -FunctionName $FunctionName -Variant $Variant)")
        $er = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'GkDelegatedOnly', [System.Management.Automation.ErrorCategory]::PermissionDenied, $FunctionName)
        $thrower.ThrowTerminatingError($er)
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
        $ex = [System.Exception]::new(
            "Missing Graph scope(s) for ${FunctionName}: $detail. Run: $(Get-GkConnectCommandHint -FunctionName $FunctionName -Variant $Variant)")
        $er = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'GkMissingScope', [System.Management.Automation.ErrorCategory]::PermissionDenied, $FunctionName)
        $thrower.ThrowTerminatingError($er)
    }

    return $ctx
}

function Resolve-GkScopeMapKey {
    <#
    .SYNOPSIS
        Resolve the $script:GkScopeMap key for a function and optional action variant.
    .DESCRIPTION
        Prefers the action-specific '<FunctionName>:<Variant>' entry and falls back to the plain
        '<FunctionName>' entry. Returns $null when neither is mapped.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $FunctionName,
        [string] $Variant
    )
    if ($Variant) {
        $keyed = "${FunctionName}:${Variant}"
        if ($script:GkScopeMap.ContainsKey($keyed)) { return $keyed }
    }
    if ($script:GkScopeMap.ContainsKey($FunctionName)) { return $FunctionName }
    return $null
}

function Get-GkConnectCommandHint {
    <#
    .SYNOPSIS
        Build the remediation instruction shown when a connection/scope pre-flight fails.
    .DESCRIPTION
        Leads with Connect-GkGraph -ForCommand, which derives the scope set from the scope map so
        the user never hand-assembles scopes, and keeps the equivalent raw Connect-MgGraph call as
        a secondary note for anyone who connects their own way.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $FunctionName,
        [string] $Variant
    )
    $scopes = Get-GkConnectScopeHint -FunctionName $FunctionName -Variant $Variant
    return "Connect-GkGraph -ForCommand $FunctionName  (or connect your own way with: Connect-MgGraph -Scopes $scopes)"
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
        [Parameter(Mandatory)] [string] $FunctionName,
        [string] $Variant
    )
    $mapKey = Resolve-GkScopeMapKey -FunctionName $FunctionName -Variant $Variant
    if (-not $mapKey) { return 'User.Read.All' }
    $entry = $script:GkScopeMap[$mapKey]
    $scopes = foreach ($group in $entry.Groups) { @($group.Any)[0] }
    $scopes = @($scopes | Where-Object { $_ } | Select-Object -Unique)
    if (-not $scopes) { return 'User.Read' }
    return ($scopes -join ',')
}
