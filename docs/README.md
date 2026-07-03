# PSGraphKit cmdlet reference

Auto-generated from each cmdlet's comment-based help by ``build/Build-GkDocs.ps1``.
Do not edit these files by hand — edit the function help and regenerate.

| Cmdlet | Synopsis |
|--------|----------|
| [Connect-GkGraph](Connect-GkGraph.md) | Connect to Microsoft Graph for PSGraphKit — a thin wrapper over Connect-MgGraph that can derive the required scopes from the cmdlets you intend to run. |
| [Disable-GkStaleDevice](Disable-GkStaleDevice.md) | Disable (default) or delete stale Entra devices. |
| [Disable-GkStaleUser](Disable-GkStaleUser.md) | Block sign-in for one or more users by setting accountEnabled = false. |
| [Export-GkTenantAssessment](Export-GkTenantAssessment.md) | Run the PSGraphKit read suite and export a single self-contained HTML assessment (and optionally CSVs) — an engagement deliverable. |
| [Get-GkAdministrativeUnit](Get-GkAdministrativeUnit.md) | Report administrative units with membership type, visibility, and member count. |
| [Get-GkAdminRoleAssignment](Get-GkAdminRoleAssignment.md) | Report Entra directory role assignments — active, PIM-eligible, and PIM active/time-bound — with the assigned principal and role resolved. |
| [Get-GkAppRegistrationReport](Get-GkAppRegistrationReport.md) | Report app registrations with credential (secret/certificate) expiry and high-privilege API permissions. |
| [Get-GkAuthMethodPolicy](Get-GkAuthMethodPolicy.md) | Report the tenant authentication-methods policy: which methods are enabled or disabled. |
| [Get-GkAuthStrengthPolicy](Get-GkAuthStrengthPolicy.md) | Report authentication strength policies (built-in and custom) and their allowed method combinations. |
| [Get-GkCaPolicyReport](Get-GkCaPolicyReport.md) | Report Conditional Access policies with their state and human-readable summaries of the targeted users/apps and the grant/session controls. |
| [Get-GkConditionalAccessTemplate](Get-GkConditionalAccessTemplate.md) | Report Microsoft's built-in Conditional Access policy templates. |
| [Get-GkConnectionInfo](Get-GkConnectionInfo.md) | Show the current Microsoft Graph session: identity, auth type, granted scopes, and (for delegated sessions) the signed-in admin's active directory roles. |
| [Get-GkConsentRequest](Get-GkConsentRequest.md) | Report pending admin-consent requests (apps waiting for an administrator to grant permissions). |
| [Get-GkCrossTenantAccess](Get-GkCrossTenantAccess.md) | Report cross-tenant access (B2B) settings: the default policy and any partner overrides. |
| [Get-GkCustomRole](Get-GkCustomRole.md) | Report custom (non-built-in) directory role definitions and their permissions. |
| [Get-GkDeviceInventory](Get-GkDeviceInventory.md) | Inventory Entra-registered/joined devices with OS, join type, last activity, and a stale flag. |
| [Get-GkDirectoryAudit](Get-GkDirectoryAudit.md) | Report directory audit events (who changed what) over a recent window. |
| [Get-GkDomain](Get-GkDomain.md) | Report the tenant's domains with verification status and authentication (managed/federated) type. |
| [Get-GkExternalCollaborationSetting](Get-GkExternalCollaborationSetting.md) | Report the tenant's external-collaboration and default-user-permission settings. |
| [Get-GkGroupExpirationPolicy](Get-GkGroupExpirationPolicy.md) | Report the Microsoft 365 group expiration (lifecycle) policy, if one is configured. |
| [Get-GkGroupReport](Get-GkGroupReport.md) | Report groups with their type (Microsoft 365 / security / distribution / dynamic), membership count, owners, and an ownerless flag. |
| [Get-GkGuestInventory](Get-GkGuestInventory.md) | Inventory guest (external) accounts with their sponsor, invitation state, last sign-in, and inactivity/age in days. |
| [Get-GkInactiveApp](Get-GkInactiveApp.md) | Report enterprise apps / service principals with no recent sign-in activity (decommission candidates). |
| [Get-GkLegacyAuthSignIn](Get-GkLegacyAuthSignIn.md) | Report sign-ins that used legacy authentication clients — a prime attack vector. |
| [Get-GkLicenseAssignmentError](Get-GkLicenseAssignmentError.md) | Report users whose license assignments are in an error state. |
| [Get-GkLicenseOverview](Get-GkLicenseOverview.md) | Report subscribed license SKUs with enabled/assigned/available counts, and optionally the number of disabled-but-licensed users per SKU. |
| [Get-GkNamedLocation](Get-GkNamedLocation.md) | Report Conditional Access named locations (IP ranges and countries). |
| [Get-GkPrivilegedRoleMember](Get-GkPrivilegedRoleMember.md) | Report members of highly privileged directory roles, flagging permanent (non-PIM) assignments. |
| [Get-GkRiskDetection](Get-GkRiskDetection.md) | Report Microsoft Entra ID Protection risk detections (e.g. impossible travel, leaked credentials, anonymous IP). |
| [Get-GkRiskyUser](Get-GkRiskyUser.md) | Report users flagged by Microsoft Entra ID Protection with their risk level and state. |
| [Get-GkRoleAssignableGroup](Get-GkRoleAssignableGroup.md) | Report role-assignable ("privileged") groups and their owners, flagging ownerless ones. |
| [Get-GkSecureScore](Get-GkSecureScore.md) | Report the tenant's latest Microsoft Secure Score, or the per-control breakdown. |
| [Get-GkServicePrincipalReport](Get-GkServicePrincipalReport.md) | Report service principals (enterprise apps) with type, state, and optionally their tenant-wide OAuth2 consent grants. |
| [Get-GkSignInReport](Get-GkSignInReport.md) | Report Entra sign-ins over a recent window, with risk and Conditional Access status. |
| [Get-GkStaleAppCredential](Get-GkStaleAppCredential.md) | Report app credentials (secrets/certificates) that have never been used or are long unused. |
| [Get-GkStaleUser](Get-GkStaleUser.md) | Report users with no sign-in activity for a threshold number of days, flagging disabled and guest accounts. |
| [Get-GkSubscription](Get-GkSubscription.md) | Report tenant subscriptions with their renewal/expiry date and status. |
| [Get-GkTenantInfo](Get-GkTenantInfo.md) | Report high-level tenant information: name, type, directory size, sync status, contacts. |
| [Get-GkUserAccessReport](Get-GkUserAccessReport.md) | Report a single user's full access footprint: group memberships, directory roles, licenses, and application role assignments. |
| [Get-GkUserMfaStatus](Get-GkUserMfaStatus.md) | Report per-user authentication-method registration and MFA capability from the authentication methods registration report. |
| [Remove-GkAdminRoleAssignment](Remove-GkAdminRoleAssignment.md) | Remove a directory role assignment — direct active, PIM-eligible, or PIM active. |
| [Remove-GkConsentGrant](Remove-GkConsentGrant.md) | Revoke a delegated OAuth2 permission grant (consent). |
| [Remove-GkStaleGuest](Remove-GkStaleGuest.md) | Disable (default) or delete stale guest accounts, with a guest-type safety check. |
| [Remove-GkUserLicense](Remove-GkUserLicense.md) | Remove one or more license SKUs from users, reclaiming the seats. |
| [Reset-GkAppCredential](Reset-GkAppCredential.md) | Add or remove an app registration's client secret. |
| [Revoke-GkUserSession](Revoke-GkUserSession.md) | Revoke the active sign-in sessions (refresh tokens) of one or more users, forcing re-authentication. |
| [Set-GkGroupOwner](Set-GkGroupOwner.md) | Add an owner to one or more groups (e.g. to remediate ownerless groups). |
