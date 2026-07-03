@{
    RootModule        = 'PSGraphKit.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = 'b4e2f1a7-9c3d-4e6b-8a1f-2d5c7e9b0a44'
    Author            = 'Martin Welen'
    CompanyName       = 'Welen'
    Copyright         = '(c) 2026 Martin Welen. MIT License.'
    Description       = 'Curated PowerShell cmdlets for everyday Entra ID / Microsoft Graph administration and reporting. A hand-built, admin-intention layer over the Microsoft Graph SDK. Phase 1: read-only reporting and inventory.'

    PowerShellVersion = '7.4'

    # Dependency: Microsoft.Graph.Authentication ONLY (for Connect-MgGraph / Invoke-MgGraphRequest).
    # Do NOT add the Microsoft.Graph meta-module or per-resource SDK modules.
    RequiredModules   = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.10.0' }
    )

    FormatsToProcess  = @('Formats\PSGraphKit.Format.ps1xml')

    # Explicit export list — updated as each function lands (priority order).
    FunctionsToExport = @(
        'Connect-GkGraph',
        'Revoke-GkUserSession',
        'Disable-GkStaleUser',
        'Remove-GkUserLicense',
        'Set-GkGroupOwner',
        'Remove-GkStaleGuest',
        'Disable-GkStaleDevice',
        'Reset-GkAppCredential',
        'Remove-GkAdminRoleAssignment',
        'Get-GkConnectionInfo',
        'Get-GkStaleUser',
        'Get-GkGuestInventory',
        'Get-GkLicenseOverview',
        'Get-GkAdminRoleAssignment',
        'Get-GkUserMfaStatus',
        'Get-GkUserAccessReport',
        'Get-GkAppRegistrationReport',
        'Get-GkGroupReport',
        'Get-GkCaPolicyReport',
        'Get-GkDeviceInventory',
        'Get-GkServicePrincipalReport',
        'Get-GkSignInReport',
        'Get-GkAuthMethodPolicy',
        'Get-GkNamedLocation',
        'Get-GkCrossTenantAccess',
        'Get-GkCustomRole',
        'Get-GkAdministrativeUnit',
        'Get-GkLicenseAssignmentError',
        'Get-GkSecureScore',
        'Get-GkRiskyUser',
        'Get-GkRiskDetection',
        'Get-GkDirectoryAudit',
        'Get-GkPrivilegedRoleMember',
        'Export-GkTenantAssessment'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Entra', 'EntraID', 'AzureAD', 'MicrosoftGraph', 'M365', 'Reporting', 'Inventory', 'Security')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/mwelen/PSGraphKit'
            ReleaseNotes = 'See CHANGELOG.md'
        }
    }
}
