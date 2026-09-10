function Get-GkConnectionInfo {
    <#
    .SYNOPSIS
        Show the current Microsoft Graph session: identity, auth type, granted scopes, and
        (for delegated sessions) the signed-in admin's active directory roles.

    .DESCRIPTION
        A "whoami" for PSGraphKit. Run it at the start of an engagement to confirm you are
        connected with enough privilege BEFORE generating reports, rather than discovering
        gaps mid-run. Returns a single PSGraphKit.ConnectionInfo object.

        ActiveRoles reflects ACTIVE role assignments only (delegated sessions). A role you are
        PIM-eligible for but have not activated will not appear. App-only sessions have no user
        roles, so ActiveRoles is empty and effective access is the granted application permissions.

    .PARAMETER RefreshRoles
        Bypass the per-session role cache and re-query the signed-in admin's active roles.

    .EXAMPLE
        Get-GkConnectionInfo

        Shows the connected account, tenant, auth type, scopes, and active roles.

    .EXAMPLE
        (Get-GkConnectionInfo).Scopes

        Returns just the granted scope strings — handy for scripting a pre-flight check.

    .EXAMPLE
        if (-not (Get-GkConnectionInfo).IsConnected) { Connect-MgGraph -Scopes User.Read.All,AuditLog.Read.All }

        Connect only when there is no active session.

    .OUTPUTS
        PSGraphKit.ConnectionInfo
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.ConnectionInfo')]
    param(
        [switch] $RefreshRoles
    )

    $ctx = Get-MgContext

    if (-not $ctx) {
        [pscustomobject]@{
            PSTypeName  = 'PSGraphKit.ConnectionInfo'
            IsConnected = $false
            Account     = $null
            AuthType    = $null
            TenantId    = $null
            ClientId    = $null
            AppName     = $null
            Scopes      = @()
            ActiveRoles = @()
        }
        return
    }

    $roles = @()
    if ($ctx.AuthType -eq 'Delegated') {
        $roles = @(Get-GkCurrentUserRole -Refresh:$RefreshRoles)
    }

    [pscustomobject]@{
        PSTypeName  = 'PSGraphKit.ConnectionInfo'
        IsConnected = $true
        Account     = $ctx.Account
        AuthType    = $ctx.AuthType
        TenantId    = $ctx.TenantId
        ClientId    = $ctx.ClientId
        AppName     = $ctx.AppName
        Scopes      = @($ctx.Scopes | Sort-Object)
        ActiveRoles = @($roles | Sort-Object)
    }
}
