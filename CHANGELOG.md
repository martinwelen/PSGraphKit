# Changelog

All notable changes to PSGraphKit are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
