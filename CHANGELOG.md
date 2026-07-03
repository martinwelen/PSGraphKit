# Changelog

All notable changes to PSGraphKit are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `ROADMAP.md` — planned cmdlet backlog (Phase 2 write/remediation, Phase 3 reports, Phase 4 export).
- `DESIGN-phase2.md` — endpoint- and scope-verified plan for the Phase 2+ cmdlets, plus the
  `Invoke-GkGraphRequest` changes (PATCH/DELETE) and write-safety conventions they require.

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

[Unreleased]: https://github.com/martinwelen/PSGraphKit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/martinwelen/PSGraphKit/releases/tag/v0.1.0
