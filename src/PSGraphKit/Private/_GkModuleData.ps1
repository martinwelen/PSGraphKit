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

    'Export-GkTenantAssessment' = @{
        Groups        = @()  # composes the read cmdlets, each of which validates its own scopes
        DelegatedOnly = $false
        RoleHints     = @('Global Reader')
    }

    'Revoke-GkUserSession' = @{
        Groups = @(
            @{ For = 'revoke sign-in sessions'; Any = @('User.RevokeSessions.All', 'User.ReadWrite.All', 'Directory.ReadWrite.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('User Administrator', 'Privileged Authentication Administrator')
    }

    'Disable-GkStaleUser' = @{
        Groups = @(
            @{ For = 'block user sign-in (accountEnabled)'; Any = @('User.EnableDisableAccount.All', 'User.ReadWrite.All', 'Directory.ReadWrite.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('User Administrator', 'Privileged Authentication Administrator')
    }

    'Remove-GkUserLicense' = @{
        Groups = @(
            @{ For = 'remove license assignments'; Any = @('LicenseAssignment.ReadWrite.All', 'User.ReadWrite.All', 'Directory.ReadWrite.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('License Administrator', 'User Administrator')
    }

    'Set-GkGroupOwner' = @{
        Groups = @(
            @{ For = 'add a group owner'; Any = @('Group.ReadWrite.All', 'Directory.ReadWrite.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Groups Administrator', 'User Administrator')
    }

    'Remove-GkStaleGuest' = @{
        Groups = @(
            @{ For = 'disable or delete a user'; Any = @('User.ReadWrite.All', 'Directory.ReadWrite.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('User Administrator', 'Privileged Authentication Administrator')
    }

    'Disable-GkStaleDevice' = @{
        Groups = @(
            @{ For = 'disable or delete a device'; Any = @('Directory.AccessAsUser.All', 'Device.ReadWrite.All', 'Directory.ReadWrite.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Cloud Device Administrator', 'Intune Administrator')
    }

    'Reset-GkAppCredential' = @{
        Groups = @(
            @{ For = 'manage application secrets'; Any = @('Application.ReadWrite.All', 'Directory.ReadWrite.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Application Administrator', 'Cloud Application Administrator')
    }

    'Remove-GkAdminRoleAssignment' = @{
        Groups = @(
            @{ For = 'remove role assignments (active and PIM)'; Any = @('RoleManagement.ReadWrite.Directory') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Privileged Role Administrator')
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

    'Get-GkServicePrincipalReport' = @{
        Groups = @(
            @{ For = 'read service principals (and consent grants)'; Any = @('Application.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Directory Readers', 'Cloud Application Administrator')
    }

    'Get-GkSignInReport' = @{
        Groups = @(
            @{ For = 'read sign-in logs'; Any = @('AuditLog.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Reports Reader', 'Security Reader')
    }

    'Get-GkAuthMethodPolicy' = @{
        Groups = @(
            @{ For = 'read the authentication methods policy'; Any = @('Policy.Read.AuthenticationMethod', 'Policy.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Authentication Policy Administrator')
    }

    'Get-GkNamedLocation' = @{
        Groups = @(
            @{ For = 'read named locations'; Any = @('Policy.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Security Reader', 'Conditional Access Administrator')
    }

    'Get-GkCrossTenantAccess' = @{
        Groups = @(
            @{ For = 'read cross-tenant access policy'; Any = @('Policy.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Security Reader')
    }

    'Get-GkCustomRole' = @{
        Groups = @(
            @{ For = 'read role definitions'; Any = @('RoleManagement.Read.Directory', 'RoleManagement.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Privileged Role Administrator')
    }

    'Get-GkAdministrativeUnit' = @{
        Groups = @(
            @{ For = 'read administrative units'; Any = @('AdministrativeUnit.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Directory Readers')
    }

    'Get-GkLicenseAssignmentError' = @{
        Groups = @(
            @{ For = 'read users'; Any = @('User.Read.All', 'Directory.Read.All') }
            @{ For = 'read subscribed SKUs'; Any = @('Organization.Read.All', 'LicenseAssignment.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'License Administrator')
    }

    'Get-GkSecureScore' = @{
        Groups = @(@{ For = 'read Secure Score'; Any = @('SecurityEvents.Read.All') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Security Reader')
    }

    'Get-GkRiskyUser' = @{
        Groups = @(@{ For = 'read risky users'; Any = @('IdentityRiskyUser.Read.All') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Security Reader', 'Security Operator')
    }

    'Get-GkRiskDetection' = @{
        Groups = @(@{ For = 'read risk detections'; Any = @('IdentityRiskEvent.Read.All') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Security Reader', 'Security Operator')
    }

    'Get-GkDirectoryAudit' = @{
        Groups = @(@{ For = 'read directory audit logs'; Any = @('AuditLog.Read.All') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Reports Reader', 'Security Reader')
    }

    'Get-GkPrivilegedRoleMember' = @{
        Groups = @(@{ For = 'read role assignments'; Any = @('RoleManagement.Read.All', 'RoleManagement.Read.Directory') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Privileged Role Administrator', 'Security Reader')
    }

    'Get-GkExternalCollaborationSetting' = @{
        Groups = @(@{ For = 'read the authorization policy'; Any = @('Policy.Read.All') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Security Reader')
    }

    'Get-GkRoleAssignableGroup' = @{
        Groups = @(@{ For = 'read groups and owners'; Any = @('Group.Read.All', 'Directory.Read.All') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Directory Readers')
    }

    'Get-GkLegacyAuthSignIn' = @{
        Groups = @(@{ For = 'read sign-in logs'; Any = @('AuditLog.Read.All') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Reports Reader', 'Security Reader')
    }

    'Get-GkAuthStrengthPolicy' = @{
        Groups = @(@{ For = 'read authentication strength policies'; Any = @('Policy.Read.AuthenticationMethod', 'Policy.Read.All') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Conditional Access Administrator', 'Security Reader')
    }

    'Get-GkConditionalAccessTemplate' = @{
        Groups = @(@{ For = 'read Conditional Access templates'; Any = @('Policy.Read.All') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Conditional Access Administrator', 'Security Reader')
    }

    'Get-GkInactiveApp' = @{
        Groups = @(
            @{ For = 'read service principal sign-in activity'; Any = @('AuditLog.Read.All') }
            @{ For = 'read service principals'; Any = @('Application.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Reports Reader', 'Security Reader')
    }

    'Get-GkStaleAppCredential' = @{
        Groups = @(
            @{ For = 'read app credential sign-in activity'; Any = @('AuditLog.Read.All') }
            @{ For = 'read service principals'; Any = @('Application.Read.All', 'Directory.Read.All') }
        )
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Reports Reader', 'Security Reader')
    }

    'Get-GkConsentRequest' = @{
        Groups = @(@{ For = 'read admin-consent requests'; Any = @('ConsentRequest.Read.All') })
        DelegatedOnly = $false
        RoleHints     = @('Global Reader', 'Cloud Application Administrator')
    }

    'Remove-GkConsentGrant' = @{
        Groups = @(@{ For = 'revoke delegated consent grants'; Any = @('DelegatedPermissionGrant.ReadWrite.All', 'Directory.ReadWrite.All') })
        DelegatedOnly = $false
        RoleHints     = @('Application Administrator', 'Cloud Application Administrator', 'Privileged Role Administrator')
    }
}

# Session cache for the signed-in admin's active directory roles (populated on first need).
$script:GkCurrentUserRoleCache = $null

# Directory roles considered highly privileged, for Get-GkPrivilegedRoleMember. Curated (display
# names are English in Graph); the v1.0 API has no isPrivileged flag (that is beta-only).
$script:GkPrivilegedRoleNames = @(
    'Global Administrator'
    'Privileged Role Administrator'
    'Privileged Authentication Administrator'
    'Security Administrator'
    'Conditional Access Administrator'
    'Application Administrator'
    'Cloud Application Administrator'
    'Exchange Administrator'
    'SharePoint Administrator'
    'User Administrator'
    'Authentication Administrator'
    'Helpdesk Administrator'
    'Intune Administrator'
    'Hybrid Identity Administrator'
    'Domain Name Administrator'
    'Directory Synchronization Accounts'
    'Partner Tier2 Support'
)

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
