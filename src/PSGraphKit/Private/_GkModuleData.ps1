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

    'Connect-GkGraph' = @{
        Groups        = @()  # establishes the session; nothing to pre-validate
        DelegatedOnly = $false
        RoleHints     = @()
    }

    'Get-GkConnectionInfo' = @{
        Groups       = @()  # uses /me with the User.Read baseline; no extra scope required
        DelegatedOnly = $false
        RoleHints    = @()
    }

    'Revoke-GkUserSession' = @{
        Groups = @(
            @{ For = 'revoke sign-in sessions'; Any = @('User.RevokeSessions.All', 'User.ReadWrite.All', 'Directory.ReadWrite.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('User Administrator', 'Privileged Authentication Administrator')
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

# Best-effort friendly names for common license SKU part numbers. This is a convenience
# only — the raw skuPartNumber is always the source of truth and is emitted alongside.
# Microsoft's full product-names/SKU reference is large and changes; this covers the SKUs
# an M365 consultant sees most often. Unknown part numbers fall back to the part number.
$script:GkSkuFriendlyName = @{
    'ENTERPRISEPACK'           = 'Office 365 E3'
    'ENTERPRISEPREMIUM'        = 'Office 365 E5'
    'STANDARDPACK'             = 'Office 365 E1'
    'DESKLESSPACK'             = 'Office 365 F3'
    'SPE_E3'                   = 'Microsoft 365 E3'
    'SPE_E5'                   = 'Microsoft 365 E5'
    'SPE_F1'                   = 'Microsoft 365 F3'
    'SPB'                      = 'Microsoft 365 Business Premium'
    'O365_BUSINESS_PREMIUM'    = 'Microsoft 365 Business Standard'
    'O365_BUSINESS_ESSENTIALS' = 'Microsoft 365 Business Basic'
    'AAD_PREMIUM'              = 'Microsoft Entra ID P1'
    'AAD_PREMIUM_P2'           = 'Microsoft Entra ID P2'
    'EMS'                      = 'Enterprise Mobility + Security E3'
    'EMSPREMIUM'               = 'Enterprise Mobility + Security E5'
    'EXCHANGESTANDARD'         = 'Exchange Online (Plan 1)'
    'EXCHANGEENTERPRISE'       = 'Exchange Online (Plan 2)'
    'POWER_BI_STANDARD'        = 'Power BI (free)'
    'POWER_BI_PRO'             = 'Power BI Pro'
    'FLOW_FREE'                = 'Power Automate Free'
    'MCOMEETADV'               = 'Microsoft 365 Audio Conferencing'
    'MCOEV'                    = 'Microsoft Teams Phone Standard'
    'TEAMS_EXPLORATORY'        = 'Microsoft Teams Exploratory'
    'WIN_DEF_ATP'              = 'Microsoft Defender for Endpoint'
    'IDENTITY_THREAT_PROTECTION' = 'Microsoft 365 E5 Security'
    'VISIOCLIENT'              = 'Visio Plan 2'
    'PROJECTPROFESSIONAL'      = 'Project Plan 3'
}
