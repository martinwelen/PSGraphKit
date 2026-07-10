# Changelog

All notable changes to PSGraphKit are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.4] - 2026-07-10

### Added
- `-First <N>` on `Get-GkSignInReport` and `Get-GkDirectoryAudit`: return only the N most-recent
  events (Graph returns these logs newest-first), stopping pagination early for a fast, bounded look
  at a high-volume tenant. Applied before the client-side refinements (`-FailedOnly`/`-RiskyOnly`,
  `-InitiatedBy`). Backed by a new optional `-MaxResult` cap in the internal request helper; the
  `-Days` window and default behavior (no cap) are unchanged.

## [0.3.3] - 2026-07-10

Performance patch: three read cmdlets did far more Graph work than needed. No output shape or scope
changes. Surfaced by the new live test protocol (below) reporting their per-cmdlet run time.

### Changed
- `Get-GkSecureScore` reads only the first page of `/security/secureScores` instead of following the
  nextLink through ~90 days of history to use a single day (~113s → ~1s on a live tenant).
- `Get-GkGroupReport` expands owners on the group-list query (`$expand=owners`) instead of a per-group
  `GET /groups/{id}/owners`, removing an N+1 that dominated runtime on large tenants. Owners for a group
  with more than ~20 owners may be truncated by Graph's expand cap; `IsOwnerless` is unaffected.
- `Get-GkLegacyAuthSignIn` filters to legacy client apps server-side (a `clientAppUsed` `$filter`)
  instead of downloading the whole sign-in window and discarding most of it.

### Added
- `build/Invoke-GkTestProtocol.ps1` + `docs/TEST-PROTOCOL.md`: a read-only live validation protocol
  that checks every read cmdlet's returned rows for type, content (no all-null "hollow" rows), and key
  fields, and documents the unit + live test layers and the release gate.

## [0.3.2] - 2026-07-07

Patch release: fixes two report cmdlets that returned empty rows. No API surface or scope changes.

### Fixed
- `Get-GkSecureScore` and `Get-GkTenantInfo` returned a row of zeros/blank fields instead of the
  tenant's actual data. Both selected the first item of a Graph collection with
  `@(...) | Select-Object -First 1`; because the internal request helper returns a page as a single
  non-unrolled array object, that expression yielded the whole array rather than its first element,
  so every field resolved to null. Both now index the assigned result directly.
- The unit tests for both cmdlets now drive the real request/pagination path (mocking only the
  low-level HTTP seam), so this class of consumption bug is caught rather than masked.

## [0.3.1] - 2026-07-03

First PowerShell Gallery release. Adds the professional release kit and brand package; no cmdlet
behavior changes.

### Added
- `about_PSGraphKit` conceptual help topic (`Get-Help about_PSGraphKit`).
- README install section and status badges; `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  and GitHub issue/PR templates.
- CI now runs on Windows, Linux, and macOS with code coverage; a tag-triggered workflow publishes
  to the PowerShell Gallery.
- Brand assets under `assets/` (icon, lockups, README banners, social preview, favicons, brand
  sheet); manifest `IconUri` for the Gallery listing and a README hero banner (light/dark).

### Fixed
- Manifest `ProjectUri` pointed to the wrong GitHub account (`mwelen` → `martinwelen`).

## [0.3.0] - 2026-07-03

20 new cmdlets across five themes — security posture/risk, access & CA hardening, apps/consent/
credentials, tenant/domains/licensing lifecycle, and membership/invitation writes. 50 cmdlets total;
all endpoint- and scope-verified against Microsoft Learn and validated live. Dependency:
Microsoft.Graph.Authentication only.

### Added
- Security posture & risk reports: `Get-GkSecureScore` (latest score + per-control breakdown),
  `Get-GkRiskyUser` (P2), `Get-GkRiskDetection` (P1+), `Get-GkDirectoryAudit` (who-changed-what),
  `Get-GkPrivilegedRoleMember` (privileged role holders, flags permanent/non-PIM).
- Access & CA hardening reports: `Get-GkExternalCollaborationSetting` (guest-invite + default-user
  permissions), `Get-GkRoleAssignableGroup` (privileged groups + ownerless flag), `Get-GkLegacyAuthSignIn`
  (sign-ins using legacy protocols), `Get-GkAuthStrengthPolicy`, `Get-GkConditionalAccessTemplate`.
- Apps, consent & credentials: `Get-GkInactiveApp` (beta SP sign-in activity), `Get-GkStaleAppCredential`
  (beta app-credential activity), `Get-GkConsentRequest` (pending admin consent), and the write cmdlet
  `Remove-GkConsentGrant` (revoke a delegated consent grant).
- Tenant, domains & licensing lifecycle: `Get-GkTenantInfo` (/organization), `Get-GkDomain` (verified +
  federation), `Get-GkSubscription` (renewal/expiry via nextLifecycleDateTime), `Get-GkGroupExpirationPolicy`.
- Membership & invitation write cmdlets: `New-GkGuestInvitation` (POST /invitations, returns redeem URL),
  `Add-GkGroupMember` / `Remove-GkGroupMember` (/groups/{id}/members/$ref).

## [0.2.0] - 2026-07-03

Phase 2 write/remediation, Phase 3 reports, and the Phase 4 assessment export. 29 cmdlets;
validated end-to-end against a live tenant. Dependency: Microsoft.Graph.Authentication only.

### Added
- `ROADMAP.md` — planned cmdlet backlog (Phase 2 write/remediation, Phase 3 reports, Phase 4 export).
- `DESIGN-phase2.md` — endpoint- and scope-verified plan for the Phase 2+ cmdlets, plus the
  `Invoke-GkGraphRequest` changes (PATCH/DELETE) and write-safety conventions they require.
- `Revoke-GkUserSession` — first Phase 2 write cmdlet: revokes users' sign-in sessions
  (POST /users/{id}/revokeSignInSessions). SupportsShouldProcess (-WhatIf/-Confirm), pipeline
  input, per-user PSGraphKit.SessionRevokeResult, warn-and-continue on failure.
- `Disable-GkStaleUser` — block sign-in for users (PATCH /users/{id} accountEnabled=false), same
  write pattern; per-user PSGraphKit.UserDisableResult. Composes with `Get-GkStaleUser`.
- `Remove-GkUserLicense` — reclaim license SKUs from users (POST /users/{id}/assignLicense with
  removeLicenses); per-user PSGraphKit.LicenseRemoveResult. Composes with `Get-GkLicenseOverview`.
- `Set-GkGroupOwner` — add an owner to groups (POST /groups/{id}/owners/$ref); per-group
  PSGraphKit.GroupOwnerResult. Composes with `Get-GkGroupReport -OwnerlessOnly`.
- `Remove-GkStaleGuest` — disable (default) or `-Delete` (soft) stale guests, with a `userType eq
  Guest` safety check (`-Force` overrides); PSGraphKit.GuestRemovalResult.
- `Disable-GkStaleDevice` — disable (default) or `-Delete` (soft) devices; PSGraphKit.DeviceDisableResult.
- `Reset-GkAppCredential` — add (`addPassword`, returns secretText once) or remove (`removePassword`)
  an app client secret; PSGraphKit.AppCredentialResult. Certificate rotation is out of scope.
- `Remove-GkAdminRoleAssignment` — remove a role assignment: DELETE for direct active, `adminRemove`
  request for PIM eligible/active; PSGraphKit.RoleRemovalResult.
- Phase 3 reports: `Get-GkServicePrincipalReport` (enterprise apps + optional consent grants, flags
  tenant-wide AllPrincipals consent), `Get-GkSignInReport` (audit sign-ins; P1/P2), `Get-GkAuthMethodPolicy`
  (per-method state), `Get-GkNamedLocation`, `Get-GkCrossTenantAccess`, `Get-GkCustomRole`,
  `Get-GkAdministrativeUnit`, `Get-GkLicenseAssignmentError`.
- Phase 4: `Export-GkTenantAssessment` — runs the read suite into one self-contained HTML report
  (inline CSS, no external assets) and optional per-section CSVs; a failing section is noted, not fatal.
  Uses only Microsoft.PowerShell.Utility.

### Changed
- `Invoke-GkGraphRequest` now supports PATCH and DELETE (and only paginates GET), enabling write
  cmdlets; 204 No Content responses return cleanly.
- `Get-GkAdminRoleAssignment` output now includes `AssignmentId` (the roleAssignment id), so
  `Remove-GkAdminRoleAssignment` can pipe directly from the report.

## [0.1.0] - 2026-07-03

Phase 1 — read-only Entra ID / Microsoft Graph reporting. 12 cmdlets, validated end-to-end
against a live tenant. Dependency: Microsoft.Graph.Authentication only.

### Added
- `Connect-GkGraph` — optional connect helper over Connect-MgGraph that derives the required scopes
  from the cmdlets you plan to run (`-ForCommand`) or the whole module (`-AllCommands`), and supports
  app-only auth (`-ClientId`/`-TenantId`/`-CertificateThumbprint`/`-Certificate`); returns the session.
- Project scaffold: module manifest, root loader, CI (PSScriptAnalyzer + Pester), analyzer settings.
- Internal `Invoke-GkGraphRequest` — single Graph chokepoint: pagination, 429/503 backoff,
  `ConsistencyLevel` re-injection on paged requests, curated permission/role error translation.
- Internal `Test-GkConnection` — pre-flight scope + auth-type validation with actionable errors.
- Internal `Get-GkCurrentUserRole` — session-cached lookup of the signed-in admin's active roles,
  used to make 403 messages name what you have vs. what the operation needs.
- `Get-GkConnectionInfo` — "whoami" for the current Graph session (identity, auth type, scopes, roles).
- `Get-GkStaleUser` — users with no sign-in for N days (from signInActivity), flagging disabled and
  guest accounts; computes LastActivity/InactiveDays/NeverSignedIn; warns when P1/P2 signInActivity
  data is unavailable. `-UserType`, `-IncludeAll`, `-AsReport`.
- `Get-GkGuestInventory` — guest accounts with sponsor (via /users/{id}/sponsors), invitation state,
  account age, and inactivity. `-StaleOnly`, `-SkipSponsor` (avoids the per-guest N+1), `-AsReport`;
  warns and continues when a sponsor lookup is denied.
- `Get-GkLicenseOverview` — subscribed SKUs with enabled/assigned/available seat counts,
  warning/suspended units, and best-effort friendly product names; `-IncludeDisabledLicensed`
  counts licenses held by disabled accounts (per-SKU user query). `-AsReport`.
- `Get-GkAdminRoleAssignment` — active, PIM-eligible, and PIM time-bound directory role
  assignments via the roleManagement RBAC API, with principal/role resolved and directory scope;
  `-AssignmentKind`, `-RoleName`; warns and continues when PIM (P2) endpoints are unavailable.
- `Get-GkUserMfaStatus` — per-user MFA capability and registered methods from the
  userRegistrationDetails report (AuditLog.Read.All); IsMfaCapable vs IsMfaRegistered, SSPR and
  passwordless flags; `-NotMfaCapableOnly`/`-AdminsOnly` server-side filters, `-AsReport`.
- `Get-GkUserAccessReport` — one user's full footprint: groups and directory roles (from
  transitiveMemberOf), licenses, and app role assignments, with counts. Pipeline-friendly
  (`-UserId` by value/property); delegated-only (licenseDetails); per-facet warn-and-continue.
- `Get-GkAppRegistrationReport` — app registrations with secret/certificate expiry (counts, earliest
  expiry, expired/expiring-soon) and high-privilege application permissions resolved live against each
  resource service principal (GUIDs never guessed, cached per run). `-ExpiringOnly`/`-ExpiringInDays`,
  `-HighPrivilegeOnly`, `-SkipPermissionResolution`, `-AsReport`.
- `Get-GkGroupReport` — groups classified by type (Microsoft365/Security/MailEnabledSecurity/
  Distribution) with dynamic flag, membership count (/members/$count), owners, and ownerless flag.
  `-GroupType`, `-OwnerlessOnly`, `-SkipMemberCount`, `-AsReport`.
- `Get-GkCaPolicyReport` — Conditional Access policies with state and readable summaries of targeted
  users/apps, grant controls (e.g. "mfa AND compliantDevice" / "Block"), and enabled session controls.
  `-State` filter (Enabled/Disabled/ReportOnly), `-AsReport`.
- `Get-GkDeviceInventory` — Entra devices with OS, join type (trustType AzureAd/ServerAd/Workplace
  mapped to AzureADJoined/HybridJoined/Registered), compliance/management/ownership, and inactivity
  from approximateLastSignInDateTime. `-StaleOnly`/`-StaleDays`, `-JoinType`, `-AsReport`.
- `docs/` — per-cmdlet markdown reference (PlatyPS-style) generated from comment-based help by
  `build/Build-GkDocs.ps1`, kept in sync by a CI test.
- `build/Invoke-GkSmokeTest.ps1` — read-only live smoke test that exercises every cmdlet against a
  real tenant and prints a per-cmdlet OK/WARN/FAIL summary.

### Fixed
- `Get-GkUserAccessReport` now percent-encodes the user id in request URLs, so guest UPNs containing
  `#` (e.g. `user_x.com#EXT#@tenant.onmicrosoft.com`) are no longer truncated at the `#` fragment.
- `Get-GkAdminRoleAssignment` no longer expands both `principal` and `roleDefinition` in one query
  (Graph allows only one `$expand`); it expands `principal` and resolves role names from a
  `roleDefinitions` lookup. (Found by live smoke test — Graph 400 "Only one property can be expanded".)
- `Get-GkUserAccessReport` no longer requests `@odata.type` in the `transitiveMemberOf` `$select`
  (Graph rejects it; it is auto-included for derived types). (Found by live smoke test — Graph 400.)

[Unreleased]: https://github.com/martinwelen/PSGraphKit/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/martinwelen/PSGraphKit/releases/tag/v0.3.1
[0.3.0]: https://github.com/martinwelen/PSGraphKit/releases/tag/v0.3.0
[0.2.0]: https://github.com/martinwelen/PSGraphKit/releases/tag/v0.2.0
[0.1.0]: https://github.com/martinwelen/PSGraphKit/releases/tag/v0.1.0
