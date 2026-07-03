# PSGraphKit Roadmap

Backlog of planned cmdlets beyond the Phase 1 read-only baseline (v0.1.0). Items are grouped
by theme and are intentions, not commitments — each is designed and endpoint-verified against
Microsoft Learn before implementation (see `DESIGN.md` for the working method).

Status legend: **shipped** · **planned** · **idea**

---

## Phase 1 — read-only reporting (shipped, v0.1.0)

`Connect-GkGraph`, `Get-GkConnectionInfo`, `Get-GkStaleUser`, `Get-GkGuestInventory`,
`Get-GkLicenseOverview`, `Get-GkAdminRoleAssignment`, `Get-GkUserMfaStatus`,
`Get-GkUserAccessReport`, `Get-GkAppRegistrationReport`, `Get-GkGroupReport`,
`Get-GkCaPolicyReport`, `Get-GkDeviceInventory`.

---

## Phase 2 — write / remediation (planned)

Action counterparts to the Phase 1 reports. All are state-changing and outward-facing, so each
supports `-WhatIf` / `-Confirm` (SupportsShouldProcess) and requires an explicit opt-in for bulk
runs. Designed to compose with the reports (`Get-Gk… | <action>`).

| Cmdlet | Remediates | Action |
|--------|-----------|--------|
| `Disable-GkStaleUser` | `Get-GkStaleUser` | block sign-in (accountEnabled = false) |
| `Remove-GkUserLicense` | `Get-GkLicenseOverview` | reclaim licenses from disabled/stale users |
| `Set-GkGroupOwner` | `Get-GkGroupReport` | add owner(s) to ownerless groups |
| `Remove-GkStaleGuest` | `Get-GkGuestInventory` | disable or remove stale guest accounts |
| `Disable-GkStaleDevice` | `Get-GkDeviceInventory` | disable or delete stale devices |
| `Revoke-GkUserSession` | `Get-GkUserMfaStatus` | revoke sign-in sessions for at-risk users |
| `Reset-GkAppCredential` | `Get-GkAppRegistrationReport` | rotate an expiring secret/certificate |
| `Remove-GkAdminRoleAssignment` | `Get-GkAdminRoleAssignment` | remove an active/eligible role |

---

## Phase 3 — broader read coverage (idea)

Lower-risk reports that widen the assessment surface.

- `Get-GkServicePrincipalReport` — enterprise apps and their OAuth2 consent grants
- `Get-GkRiskyConsentGrant` — over-privileged / illegal delegated consents
- `Get-GkSignInReport` — risky and failed sign-ins (audit log)
- `Get-GkAuthMethodPolicy` — tenant authentication-methods policy posture
- `Get-GkNamedLocation` — Conditional Access named locations
- `Get-GkCrossTenantAccess` — B2B / cross-tenant access settings
- `Get-GkCustomRole` — custom directory role definitions
- `Get-GkAdministrativeUnit` — administrative units and scoped admins
- `Get-GkLicenseAssignmentError` — users with failing license assignments

---

## Phase 4 — engagement deliverables (idea)

- `Export-GkTenantAssessment` — run the read suite into a single self-contained HTML (and CSV)
  workbook suitable to hand to a client. Highest-value orchestration item; pure read.
- `Get-GkSecurityBaseline` — compare tenant posture against a configurable checklist.

---

## Cross-cutting considerations

- **Dependency constraint holds:** Microsoft.Graph.Authentication only. Exports use native
  `ConvertTo-Html` / `Export-Csv`; no Excel/reporting module dependency.
- **Write safety:** every state-changing cmdlet is SupportsShouldProcess, defaults to per-item
  confirmation, and surfaces the exact change before making it.
- **Scopes:** write cmdlets require write scopes (e.g. `User.ReadWrite.All`) declared in the same
  capability-group scope map; `Test-GkConnection` validates them the same way.
