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
