function Connect-GkGraph {
    <#
    .SYNOPSIS
        Connect to Microsoft Graph for PSGraphKit — a thin wrapper over Connect-MgGraph that can
        derive the required scopes from the cmdlets you intend to run.

    .DESCRIPTION
        PSGraphKit is auth-agnostic and works with any Connect-MgGraph session, so this helper is
        optional. Its value is scope derivation: instead of hand-assembling a -Scopes list, name the
        cmdlets you plan to use (-ForCommand) or ask for everything (-AllCommands) and it computes the
        least-privileged scope set from the module's scope map, then connects delegated.

        For app-only (enterprise app) authentication, pass -ClientId, -TenantId and a certificate
        (-CertificateThumbprint or -Certificate); scopes are consented on the app registration in
        that model, so any -Scopes/-ForCommand input is ignored. After connecting, the current
        session is returned as a PSGraphKit.ConnectionInfo object.

    .PARAMETER Scopes
        Explicit delegated scopes to request (passed through to Connect-MgGraph).

    .PARAMETER ForCommand
        One or more PSGraphKit cmdlet names; their required scopes are derived from the scope map and
        unioned into the request. Combine with -Scopes to add extras.

    .PARAMETER AllCommands
        Request the union of scopes for every PSGraphKit cmdlet (the full read-only footprint).

    .PARAMETER TenantId
        Target tenant (GUID or domain). Optional for delegated, required for app-only.

    .PARAMETER ClientId
        App (client) ID for app-only authentication.

    .PARAMETER CertificateThumbprint
        Thumbprint of a certificate in the current user/machine store, for app-only authentication.

    .PARAMETER Certificate
        An X509Certificate2 object, for app-only authentication.

    .PARAMETER NoWelcome
        Suppress the Connect-MgGraph welcome banner.

    .EXAMPLE
        Connect-GkGraph -ForCommand Get-GkStaleUser, Get-GkGuestInventory

        Connect delegated with exactly the scopes those two cmdlets need.

    .EXAMPLE
        Connect-GkGraph -AllCommands

        Connect delegated with the full read-only scope set for every PSGraphKit cmdlet.

    .EXAMPLE
        Connect-GkGraph -ClientId $appId -TenantId contoso.onmicrosoft.com -CertificateThumbprint $thumb

        Connect app-only (enterprise app) with a certificate.

    .OUTPUTS
        PSGraphKit.ConnectionInfo
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.ConnectionInfo')]
    param(
        [string[]] $Scopes,

        [string[]] $ForCommand,

        [switch] $AllCommands,

        [string] $TenantId,

        [string] $ClientId,

        [string] $CertificateThumbprint,

        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,

        [switch] $NoWelcome
    )

    # Derive the delegated scope set.
    $resolved = [System.Collections.Generic.List[string]]::new()
    foreach ($s in @($Scopes)) {
        if ($s -and $resolved -notcontains $s) { $resolved.Add($s) }
    }
    $commands = @()
    if ($AllCommands)     { $commands = @($script:GkScopeMap.Keys) }
    elseif ($ForCommand)  { $commands = $ForCommand }
    foreach ($c in $commands) {
        # A cmdlet whose scopes depend on the action it performs also has '<name>:<variant>' entries
        # (e.g. Remove-GkStaleGuest:Delete). Naming the cmdlet grants what every one of its paths
        # needs, so -ForCommand never leaves the caller short on one of them.
        $keys = @($script:GkScopeMap.Keys | Where-Object { $_ -eq $c -or $_ -like "${c}:*" })
        if ($keys.Count -eq 0) {
            Write-Warning "Unknown PSGraphKit cmdlet '$c' — no scopes derived for it."
            continue
        }
        foreach ($k in $keys) {
            foreach ($s in ((Get-GkConnectScopeHint -FunctionName $k) -split ',')) {
                $s = $s.Trim()
                if ($s -and $resolved -notcontains $s) { $resolved.Add($s) }
            }
        }
    }

    $connectParams = @{}
    if ($NoWelcome) { $connectParams['NoWelcome'] = $true }

    if ($ClientId) {
        # App-only (enterprise app) authentication.
        if (-not $TenantId) {
            throw "App-only authentication (-ClientId) requires -TenantId."
        }
        if (-not $CertificateThumbprint -and -not $Certificate) {
            throw "App-only authentication requires a certificate: pass -CertificateThumbprint or -Certificate."
        }
        $connectParams['ClientId'] = $ClientId
        $connectParams['TenantId'] = $TenantId
        if ($CertificateThumbprint) { $connectParams['CertificateThumbprint'] = $CertificateThumbprint }
        else                        { $connectParams['Certificate'] = $Certificate }
        if ($resolved.Count -gt 0) {
            Write-Verbose 'Scopes are ignored for app-only authentication; permissions come from the app registration.'
        }
    }
    else {
        # Delegated authentication.
        if ($resolved.Count -eq 0) {
            throw "Specify the scopes to request: use -Scopes, -ForCommand <cmdlet...>, or -AllCommands."
        }
        $connectParams['Scopes'] = $resolved.ToArray()
        if ($TenantId) { $connectParams['TenantId'] = $TenantId }
    }

    Connect-MgGraph @connectParams

    Get-GkConnectionInfo
}
