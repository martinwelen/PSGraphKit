# Module-level data: Graph base URI, scope map, role hints.
# Dot-sourced into module scope by PSGraphKit.psm1, so $script:* is module-wide state.

$script:GkGraphBaseUri = 'https://graph.microsoft.com'

# Per-function scope requirements, expressed as CAPABILITY GROUPS.
# The caller must hold at least one scope from EACH group's 'Any' list. Modelling it this
# way lets a broad scope (e.g. Directory.Read.All) satisfy a narrower need without a false
# "missing scope" failure, while still requiring genuinely distinct capabilities
# (e.g. reading users AND reading signInActivity) separately.
#
# DelegatedOnly: the underlying Graph API has no application permission — app-only sessions
# cannot serve it (currently only licenseDetails, used by Get-GkUserAccessReport).
#
# RoleHints: documented least-privileged built-in Entra roles that grant read access, used
# to enrich 403 messages. Guidance only — Global Reader is universally valid for reads, and
# an equivalent custom role also works. Sourced from each Graph "list" API doc.
$script:GkScopeMap = @{

    'Get-GkConnectionInfo' = @{
        Groups       = @()  # uses /me with the User.Read baseline; no extra scope required
        DelegatedOnly = $false
        RoleHints    = @()
    }

    'Get-GkStaleUser' = @{
        Groups = @(
            @{ For = 'read user objects';   Any = @('User.Read.All', 'Directory.Read.All') }
            @{ For = 'read signInActivity'; Any = @('AuditLog.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Reports Reader', 'Security Reader')
    }

    'Get-GkGuestInventory' = @{
        Groups = @(
            @{ For = 'read guest users and sponsors'; Any = @('User.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Directory Readers', 'Guest Inviter', 'User Administrator')
    }

    'Get-GkLicenseOverview' = @{
        Groups = @(
            @{ For = 'read subscribed SKUs';       Any = @('Organization.Read.All', 'LicenseAssignment.Read.All', 'Directory.Read.All') }
            @{ For = 'enumerate users per SKU';    Any = @('User.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Directory Readers', 'License Administrator')
    }

    'Get-GkAdminRoleAssignment' = @{
        Groups = @(
            @{ For = 'read role assignments and PIM schedules'; Any = @('RoleManagement.Read.All', 'RoleManagement.Read.Directory') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Privileged Role Administrator', 'Security Reader')
    }

    'Get-GkUserMfaStatus' = @{
        Groups = @(
            @{ For = 'read authentication method registration report'; Any = @('AuditLog.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Reports Reader', 'Authentication Policy Administrator')
    }

    'Get-GkUserAccessReport' = @{
        Groups = @(
            @{ For = 'read group and role memberships'; Any = @('User.Read.All', 'GroupMember.Read.All', 'Directory.Read.All') }
            @{ For = 'read app role assignments';       Any = @('Directory.Read.All', 'AppRoleAssignment.ReadWrite.All') }
            @{ For = 'read license details';            Any = @('LicenseAssignment.Read.All', 'User.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $true   # licenseDetails has no application permission
        RoleHints     = @('Global Reader', 'Directory Readers')
    }

    'Get-GkAppRegistrationReport' = @{
        Groups = @(
            @{ For = 'read app registrations'; Any = @('Application.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Directory Readers', 'Application Administrator', 'Cloud Application Administrator')
    }

    'Get-GkGroupReport' = @{
        Groups = @(
            @{ For = 'read groups';                  Any = @('Group.Read.All', 'Directory.Read.All') }
            @{ For = 'read group members and owners'; Any = @('GroupMember.Read.All', 'Group.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Directory Readers', 'Groups Administrator')
    }

    'Get-GkCaPolicyReport' = @{
        Groups = @(
            @{ For = 'read Conditional Access policies'; Any = @('Policy.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Security Reader', 'Security Administrator', 'Conditional Access Administrator')
    }

    'Get-GkDeviceInventory' = @{
        Groups = @(
            @{ For = 'read devices'; Any = @('Device.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Directory Readers', 'Cloud Device Administrator', 'Intune Administrator')
    }
}

# Session cache for the signed-in admin's active directory roles (populated on first need).
$script:GkCurrentUserRoleCache = $null
